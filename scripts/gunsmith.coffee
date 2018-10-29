Promise = require('promise')
Traveler = require('the-traveler').default
{ComponentType} = require('the-traveler/build/enums')
BungieAPI = require './dependencies/bungie.coffee'
GunsmithDatabase = require './dependencies/database.coffee'
ItemFormatter = require './dependencies/format.coffee'
constants = require './dependencies/constants.coffee'
strings = require './dependencies/strings.coffee'

# Load settings
console.log("Log : Initializing database")
gunsmithDB = new GunsmithDatabase
gunsmithDB.initializeDatabase()

module.exports = (robot) ->
	# Respond to requests to update the manifest
	robot.respond /(manifest|update|update manifest)$/i, (res) ->
		console.log("Log : Manual Manifest update requested")

		console.log("Log : Verifying config DM is from an authorized user")
		isConfigUser = gunsmithDB.settings.allow_admin_config is "true" and res.message.user.slack.is_admin
		isOwner = res.message.user.id is gunsmithDB.settings.owner_id
		if not isConfigUser and not isOwner
			res.send strings[gunsmithDB.settings.language].CONFIG_ACCESS_ERROR
			console.error("ERR : User is not authorized to update Manifest. Exiting")
			return

		res.send strings[gunsmithDB.settings.language].MANIFEST_UPDATE_STARTED
		gunsmithDB.loadManifestIntoDB().then ->
			console.log("Log : Manual Manifest update completed")
			res.send strings[gunsmithDB.settings.language].MANIFEST_UPDATE_COMPLETE

	# Respond to configuration changes
	robot.respond /\bconfig(?:ure|)\b(?:\s|)(.*)/i, (res) ->
		if res.message.room[0] is 'D'					
			if !res.match[1]
				console.error("ERR : Config sent with no additional parameters")
				res.send strings[gunsmithDB.settings.language].CONFIG_COMMAND_ERROR
				return

			console.log("Log : Received config DM (Input: #{res.match[1]})")

			isConfigUser = gunsmithDB.settings.allow_admin_config is "true" and res.message.user.slack.is_admin
			isOwner = res.message.user.id is gunsmithDB.settings.owner_id
			if not isConfigUser and not isOwner
				res.send strings[gunsmithDB.settings.language].CONFIG_ACCESS_ERROR
				console.error("ERR : User is not authorized to configure. Exiting")
				return
			console.log("Log : Config DM is from an authorized user")

			# Tokenize the input, trim spaces, and remove empty elements
			array = res.match[1].split ' '
			input = []
			input.push el.trim().toLowerCase() for el in array when (el.trim() isnt "")
	
			# There should only be either one or two, the variable (for reading) and the variable and its value (for writing)
			if input.length > 2 or input.length <= 0
				console.error("ERR : Incorrect number of config tokens. Exiting")
				res.send strings[gunsmithDB.settings.language].CONFIG_COMMAND_ERROR
				return

			if input[0] in constants.CONFIGURABLE_ENVIRONMENT_VARS
				console.log("Log : Config key is valid")

				# Reading a config variable from the db
				if input.length is 1
					console.log("Log : Outputting config value to user")
					res.send gunsmithDB.settings[input[0]]
				# Writing a config variable to the db
				else if input.length is 2
					if input[0] is "language"
						if input[1] not in constants.SUPPORTED_LANGUAGES
							console.log("Log : Language is not supported (#{input[1]})")
							res.send strings[gunsmithDB.settings.languyage].CONFIG_INVALID_VALUE
							return
					else if input[0] is "default_platform"
						if input[1] not in constants.SUPPORTED_PLATFORMS
							console.log("Log : Invalid config value (#{input[1]})")
							res.send strings[gunsmithDB.settings.languyage].CONFIG_INVALID_VALUE
							return
					else
						if input[1] not in constants.TRUE_FALSE
							console.log("Log : Invalid config value (#{input[1]})")
							res.send strings[gunsmithDB.settings.languyage].CONFIG_INVALID_VALUE
							return

					gunsmithDB.saveSettingToDB(input[0], input[1])
					res.send strings[gunsmithDB.settings.language].CONFIG_KEY_SAVED

					if input[0] is "language"
						res.send strings[gunsmithDB.settings.language].MANIFEST_UPDATE_STARTED
						gunsmithDB.loadManifestIntoDB().then ->
							console.log("Log : Language change Manifest update completed")
							res.send strings[gunsmithDB.settings.language].MANIFEST_UPDATE_COMPLETE
			else
				console.error("Log : Config key is invalid")
				res.send strings[gunsmithDB.settings.language].CONFIG_INVALID_KEY
		return

	# executes when any text is directed at the bot
	robot.respond /(.*)/i, (res) ->
		# Drop out we match any of the special commands
		if /help/i.test(res.match[1])
			return

		if /(?:config|configure)(?:)(.*)/i.test(res.match[1])
			return
		
		if /(manifest|update|update manifest)$/i.test(res.match[1])
			return

		console.log("Log : Gunsmith activated (Input: #{res.match[1]})")

		# Load the localized class names from the database
		gunsmithDB.getLocalizedClasses().then (localizedClassNames) =>

			# Split the input, trim spaces, and remove empty elements
			array = res.match[1].split ' '
			input = []
			input.push el.trim().toLowerCase() for el in array when (el.trim() isnt "")

			# Sanity check on number of tokens
			if input.length > 10 or input.length <= 0
				console.error("Error : Too many (or too few) tokens. Ignoring")
				robot.messageRoom("#{res.message.user.id}", strings[gunsmithDB.settings.language].GENERAL_USAGE_ERROR)
				return

			console.log("Log : Input tokenzied (Result: #{input.toString()})")

			data = {}

			selectedPlatform = null
			selectedSlotHash = null
			selectedClassHash = null
			gamerTag = null

			# Attempt to determine item slot
			removeIndex = -1
			console.log('Log : Begin item slot check')

			# Loop through the tokenized input, trying to find if any of the inputs is an item slot
			for currentArgument, index in input
				# Check to see if the current token is a valid item type
				if currentArgument of constants.ITEM_HASHES
					# If the current token is in the array, check to make sure a item has not already been specified
					if selectedSlotHash is null
						# Set the item slot and the index of the matched token
						removeIndex = index
						selectedSlotHash = constants.ITEM_HASHES[currentArgument]
					else
						# The current token is in the array, but the item slot is already set indicating
						# that the user put two item names in the input
						console.error('Error : Multiple slots specified')
						robot.messageRoom("#{res.message.user.id}", strings[gunsmithDB.settings.language].GENERAL_USAGE_ERROR)
						return
			
			# All tokens have been processed and no item slot was set, send an error message and exit
			if selectedSlotHash is null
				console.error('Error : Item slot not specified')
				robot.messageRoom("#{res.message.user.id}", strings[gunsmithDB.settings.language].GENERAL_USAGE_ERROR)
				return

			# Remove the matched token from the input array
			if removeIndex >= 0
				input.splice(removeIndex, 1)

			console.log("Log : Item slot check complete (Chosen: #{selectedSlotHash})")
			console.log("Log : Input remaining: #{input.toString()}")

			# Check to make sure there are still tokens
			removeIndex = -1
			if input.length != 0
				# Determine the gaming platform specified
				console.log('Log : Begin gaming platform check')

				# Loop through the tokenized input, trying to find if any of the inputs is a class
				for currentArgument, index in input
					# Check to see if the current token is in the item slot array
					if currentArgument of constants.GAME_PLATFORM
						# If the current token is in the array, check to make sure a class has not already been specified
						if selectedPlatform is null
							# Set the class and the index of the matched token
							removeIndex = index
							selectedPlatform = constants.GAME_PLATFORM[currentArgument]
						else
							# The current token is in the array, but the platform is already set indicating
							# that the user put two platform in the input
							console.error('Error : Multiple gaming platforms specified')
							robot.messageRoom("#{res.message.user.id}", strings[gunsmithDB.settings.language].GENERAL_USAGE_ERROR)
							return

				# Remove the matched token from the input array
				if removeIndex >= 0
					input.splice(removeIndex, 1)

				console.log("Log : Gaming platform check complete (Chosen: #{selectedPlatform})")
				console.log("Log : Input remaining: #{input.toString()}")

			# If the gaming platform is empty, we will use the default platform set in the database
			if not selectedPlatform?
				console.log("Log : Gaming platform is blank, attempting to use default platform")

				if gunsmithDB.settings.default_platform is ""
					console.error("Error: No gaming platform specified and default platform is empty")
					robot.messageRoom("#{res.message.user.id}", strings[gunsmithDB.settings.language].NO_PLATFORM_PROVIDED_ERROR)
					return

				selectedPlatform = constants.GAME_PLATFORM[gunsmithDB.settings.default_platform]
				console.log("Log : Gaming platform found (#{selectedPlatform})")		

			# Check to make sure there are still tokens
			removeIndex = -1
			if input.length != 0
				# Determine the class specified
				console.log('Log : Begin class check')

				# Loop through the tokenized input, trying to find if any of the inputs is a class
				for currentArgument, index in input
					# Check to see if the current token is in the item slot array
					if currentArgument of localizedClassNames
						# If the current token is in the array, check to make sure a class has not already been specified
						if selectedClassHash is null
							# Set the class and the index of the matched token
							removeIndex = index
							selectedClassHash = localizedClassNames[currentArgument]
						else
							# The current token is in the array, but the class is already set indicating
							# that the user put two classes in the input
							console.error('Error : Multiple of class specified')
							robot.messageRoom("#{res.message.user.id}", strings[gunsmithDB.settings.language].GENERAL_USAGE_ERROR)
							return

				# Remove the matched token from the input array
				if removeIndex >= 0
					input.splice(removeIndex, 1)

				console.log("Log : Class check complete (Chosen: #{selectedClassHash})")
				console.log("Log : Input remaining: #{input.toString()}")

			# Check to make sure there are still tokens
			if input.length != 0
				# Build the username from the remaining tokens
				console.log('Log : Building username')

				playerUsername = input.join(' ').trim()

				console.log("Log : Username build complete (Built: #{playerUsername})")

			# If the player username is empty, we will use the slack first name
			if not playerUsername?
				console.log("Log : Username is blank, attempting to use Slack profile name")
				playerUsername = res.message.user.slack.profile.first_name

				if not playerUsername?
					console.error("Error: No username specified and Slack profile name is empty")
					robot.messageRoom("#{res.message.user.id}", strings[gunsmithDB.settings.language].NO_USERNAME_PROVIDED_ERROR)
					return

				console.log("Log : Username found (#{playerUsername})")			

			console.log('Log : Starting API queries')
			bungieAPI = new BungieAPI()

			bungieAPI.getEquippedItem(selectedPlatform, playerUsername, selectedClassHash, selectedSlotHash).then (instancedItem) ->
				console.log("Log : Loaded instanced item from API (ID: #{instancedItem.item.data.itemInstanceId} Hash: #{instancedItem.item.data.itemHash})")

				gunsmithDB.getLocalizedItem(instancedItem.item.data.itemHash).then (genericItem) ->
					console.log("Log : Loaded generic item from database")

					itemFormatter = new ItemFormatter(gunsmithDB)
					itemFormatter.createItem(genericItem, instancedItem).then (createdItem) ->
						console.log("Log : Item created from generic and instance data")

						slackAttachments = []

						# Create a longform or shortform attachment based on settings
						if gunsmithDB.settings.longform_output is "true"
							slackAttachments.push itemFormatter.createItemAttachment(createdItem)
						else
							slackAttachments.push itemFormatter.createShortItemAttachment(createdItem)

						console.log("Log : Item formatted for output")

						res.send {attachments: slackAttachments}

						console.log("Log : Item response sent")

			.catch (error) ->
				console.log("ERR : #{error}")
				robot.messageRoom("#{res.message.user.id}", strings[gunsmithDB.settings.language][error])

	robot.respond /help/i, (res) ->
		sendHelp(robot, res)

	robot.respond /!help/i, (res) ->
		sendHelp(robot, res)

sendHelp = (robot, res) ->
	attachment =
		title: constants.HELP_TITLE
		text: constants.HELP_TEXT
		mrkdwn_in: ["text"]
	payload =
		message: res.message
		attachments: attachment

	robot.emit 'slack-attachment', payload