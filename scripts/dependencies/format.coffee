Promise = require('promise')
require('dotenv').load()
Traveler = require('the-traveler').default
constants = require './constants.coffee'

class ItemFormatter
	constructor: (@database) ->

	createItem: (genericItem, instancedItem) ->
		# Note: Exotic check for future reference genericItem.inventory.tierTypeHash is 2759499571
		promise = new Promise (resolve, reject) =>
			console.log("IF : Assembling properties needed for output")
			formattingPromises = []
			formattedItem = {}

			# Get item hash, name, description, and icon
			formattedItem.hash = genericItem.hash
			formattedItem.name = genericItem.displayProperties.name
			formattedItem.description = genericItem.displayProperties.description
			formattedItem.icon = genericItem.displayProperties.icon

			# Get generic/instanced item stats
			# Object.assign combines the two objects, with the right object taking prescendece.
			# In this case, that means that instance stats will overwrite generic stats
			combinedStats = Object.assign(genericItem.stats.stats, instancedItem.stats.data.stats)

			formattedItemStats = []
			statHashes = Object.keys(combinedStats)

			# Filter out junk stats
			statHashes = statHashes.filter((object) ->
				object not in constants.IGNORE_STATS)

			for currentStatHash in statHashes
				currentStat = {}
				currentStat.hash = currentStatHash
				tempPromise = @database.getLocalizedStat(currentStatHash)
				formattingPromises.push tempPromise
				currentStat.name = tempPromise
				currentStat.value = combinedStats[currentStatHash].value

				formattedItemStats.push currentStat

			formattedItem.stats = formattedItemStats
			
			# Get instanced item damage type
			damageTypeHash = instancedItem.instance.data.damageTypeHash
			if damageTypeHash?
				tempPromise = @database.getLocalizedWeaponDamageType(damageTypeHash)
				formattingPromises.push tempPromise
				formattedItem.damageName = tempPromise
				formattedItem.damageColor = constants.DAMAGE_COLOR[damageTypeHash]
			
			# Get instanced item plugs and filter out invisible ones
			instancedItemPlugTrees = instancedItem.sockets.data.sockets
			instancedItemPlugTrees = instancedItemPlugTrees.filter((object) -> object.isVisible)

			formattedItemPlugs = []
			for currentPlugTree in instancedItemPlugTrees
				# This is the only plug available on this tier, just resolve its name and add it to the array
				# Note if reusablePlugHashes is missing, this plug is a mod
				if not currentPlugTree.reusablePlugHashes? or currentPlugTree.reusablePlugHashes is 1
					currentFormattedPlugTree = []
					currentFormattedPlug = {}
					currentFormattedPlug.enabled = true
					tempPromise = @database.getLocalizedPlug(currentPlugTree.plugHash)
					formattingPromises.push tempPromise
					currentFormattedPlug.name = tempPromise

					currentFormattedPlugTree.push currentFormattedPlug
					formattedItemPlugs.push currentFormattedPlugTree
				# This is a standard plug tree (note, it may be a Masterwork or Shader at this point)
				else
					currentFormattedPlugTree = []
					currentPlugTreeHashes = currentPlugTree.reusablePlugHashes

					# In certain situations (Masterwork stat, non-blank shader) the current plug is not in the reusable hashes array
					if currentPlugTree.plugHash not in currentPlugTreeHashes
						currentPlugTreeHashes.unshift(currentPlugTree.plugHash)

					for currentPlugInTree in currentPlugTreeHashes
						currentFormattedPlug = {}
						currentFormattedPlug.enabled = (currentPlugTree.plugHash is currentPlugInTree)
						tempPromise = @database.getLocalizedPlug(currentPlugInTree)
						formattingPromises.push tempPromise
						currentFormattedPlug.name = tempPromise

						currentFormattedPlugTree.push currentFormattedPlug

					formattedItemPlugs.push currentFormattedPlugTree
			
			formattedItem.plugs = formattedItemPlugs

			Promise.all(formattingPromises).then ->
				resolve(formattedItem)

	createItemAttachment: (createdItem) ->
		# Build display name by adding element for non-kinetic/non-armor
		displayName = "#{createdItem.name}"
		displayName += " [#{createdItem.damageName._j}]" if createdItem.damageName?

		attachment = {
			title: displayName
			fallback: createdItem.description
			title_link: "https://db.destinytracker.com/d2/en/items/#{createdItem.hash}"
			color: createdItem.damageColor
			mrkdwn_in: ["text"]
			thumb_url: "https://www.bungie.net#{createdItem.icon}"
		}

		console.log("IF : Basic attachment data created from item")
		
		# Filter out plug trees that are to be discarded, such as shaders
		displayPlugs = createdItem.plugs.filter((object) -> not object[0].name._j.discard)

		# Put collapsed and uncollapsed plugs into their own treesr
		collapsedPlugTrees = displayPlugs.filter((object) -> object[0].name._j.collapse)
		uncollapsedPlugTrees = displayPlugs.filter((object) -> not object[0].name._j.collapse)

		plugText = []

		# Build the text for the collapsed plugs
		currentPlugTreeText = ""
		for currentPlugTree in collapsedPlugTrees
			currentPlugTreeText += (if currentPlugTreeText then ' | ' else '') + "*#{currentPlugTree[0].name._j.name}*"

		plugText.push currentPlugTreeText

		# Build the text for the uncollapsed plugs
		for currentPlugTree in uncollapsedPlugTrees
			currentPlugTreeText = ""
			for currentPlug in currentPlugTree
				currentPlugName = if currentPlug.enabled then "*#{currentPlug.name._j.name}*" else "#{currentPlug.name._j.name}"
				currentPlugTreeText += (if currentPlugTreeText then ' | ' else '') + currentPlugName

			plugText.push currentPlugTreeText
		
		attachment.text = plugText.join('\n')

		console.log("IF : Attachemnt text created from item plugs")

		footerStats = []
		for currentStat in createdItem.stats
			footerStats.push "#{currentStat.name._j}: #{currentStat.value}"
		
		attachment.footer = footerStats.join ', '

		console.log("IF : Attachment footer created from item stats")

		return attachment

module.exports = ItemFormatter