Promise = require('promise')
require('dotenv').load()
knex = require('knex')(
	client: 'pg'
	connection: process.env.DATABASE_URL
)
Traveler = require('the-traveler').default
constants = require './constants.coffee'

class GunsmithDatabase
	constructor: () ->
		@settings = {}

	initializeDatabase: () ->
		console.log("DB : Checking schema")

		configPromise = new Promise (resolve, reject) ->
			knex.schema.hasTable('config').then (exists) ->
				if !exists
					console.log("DB : No config table found. Creating")
					knex.schema.createTable 'config', (table) ->
						table.string('key').unique().notNullable()
						table.string('value')
						return
					.then ->
						console.log("DB : Inserting default values for config table")
						knex('config').insert([
							{key: "show_armor", value: "true"},
							{key: "allow_admin_config", value: "true"},
							{key: "longform_output", value: "true"},
							{key: "default_platform", value: ""},
							{key: "owner_id", value: ""},
							{key: "language", value: "en"},
							{key: "manifest_hash", value: ""}
						])
					.then ->
						console.log("DB : Config table created")
						resolve()
				else
					console.log("DB : Config table OK")
					resolve()

		manifestPromise = new Promise (resolve, reject) ->
			knex.schema.hasTable('manifest').then (exists) ->
				if !exists
					console.log("DB : No manifest table found. Creating")
					knex.schema.createTable 'manifest', (table) ->
						table.string('id').unique().notNullable()
						table.text('json').notNullable()
						return
					.then ->
						console.log("DB : Manifest table created")
						resolve()
				else
					console.log("DB : Manifest table OK")
					resolve()
		
		classLocalizationPromise = new Promise (resolve, reject) ->
			knex.schema.hasTable('classLocalization').then (exists) ->
				if !exists
					console.log("DB : No Class localization table found. Creating")
					knex.schema.createTable 'classLocalization', (table) ->
						table.text('id').unique().notNullable()
						table.text('name').unique().notNullable()
						return
					.then ->
						console.log("DB : Class localization table created")
						resolve()
				else
					console.log("DB : Class localization table OK")
					resolve()

		itemSlotLocalizationPromise = new Promise (resolve, reject) ->
			knex.schema.hasTable('itemSlotLocalization').then (exists) ->
				if !exists
					console.log("DB : No Item Slot localization table found. Creating")
					knex.schema.createTable 'itemSlotLocalization', (table) ->
						table.text('id').unique().notNullable()
						table.text('name').unique().notNullable()
						return
					.then ->
						console.log("DB : Item Slot localization table created")
						resolve()
				else
					console.log("DB : Item Slot localization table OK")
					resolve()

		itemStatLocalizationPromise = new Promise (resolve, reject) ->
			knex.schema.hasTable('itemStatLocalization').then (exists) ->
				if !exists
					console.log("DB : No Item Stat localization table found. Creating")
					knex.schema.createTable 'itemStatLocalization', (table) ->
						table.text('id').unique().notNullable()
						table.text('name').notNullable()
						return
					.then ->
						console.log("DB : Item Stat localization table created")
						resolve()
				else
					console.log("DB : Item Stat localization table OK")
					resolve()

		weaponDamageTypeLocalizationPromise = new Promise (resolve, reject) ->
			knex.schema.hasTable('weaponDamageTypeLocalization').then (exists) ->
				if !exists
					console.log("DB : No Weapon Damage Type localization table found. Creating")
					knex.schema.createTable 'weaponDamageTypeLocalization', (table) ->
						table.text('id').unique().notNullable()
						table.text('name').unique().notNullable()
						return
					.then ->
						console.log("DB : Weapon Damage Type localization table created")
						resolve()
				else
					console.log("DB : Weapon Damage Type localization table OK")
					resolve()	

		Promise.all([configPromise, manifestPromise, classLocalizationPromise, itemSlotLocalizationPromise, itemStatLocalizationPromise, weaponDamageTypeLocalizationPromise]).then =>
			console.log("DB : Schema check complete")
			@loadSettingsFromDB().then =>
				console.log("DB : Initialization complete")
				@loadManifestIntoDB().then =>
					console.log("DB : Startup Manifest check complete")

	loadSettingsFromDB: () ->
		console.log("DB : Attempting to load settings from database")
		knex.select().from('config').then (rows) =>
			tempSettings = {}
			for row in rows
				tempSettings[row['key']] = row['value']

			console.log("DB : Loaded settings from database")
			@settings = tempSettings

	saveSettingToDB: (key, newValue) ->
		console.log("DB : Attempting to save setting to database")
		knex('config').where('key', '=', key).update({value: newValue}).then =>
			console.log("DB : Saved setting to database")			
			@loadSettingsFromDB()

	loadManifestIntoDB: () ->
		console.log("DB : Loading current Manifest URLs")

		# Technically the API shouldn't be needed for grabbing the manifest
		# However sometimes the API throws an error if it isn't set
		traveler = new Traveler(apikey: process.env.BUNGIE_API_KEY, userAgent: "GunsmithBot")
		traveler.getDestinyManifest().then (result) =>
			language = @settings.language
			manifestURL = result.Response.mobileWorldContentPaths[language]
			manifestHash = manifestURL.match(/world_sql_content_(.*)\.content/i)

			console.log("DB : Checking saved Manifest hash against latest from API")
			if @settings.manifest_hash is manifestHash[1]
				console.log("DB : API Manifest hash matches DB manifest hash. Manifest is not out of date. Exiting")
				return

			console.log("DB : Downloading Manifest file")
			traveler.downloadManifest(manifestURL, './manifest.sqlite').then (filepath) =>
				console.log("DB : Opening Manifest file and starting dump")
				manifest = require('knex')(
					client: 'sqlite3'
					connection: filename: './manifest.sqlite'
				)

				manifestPromise = new Promise (resolve, reject) ->
					console.log("DB : Clearing old Manifest table")
					knex('manifest').delete().then ->
						# If id is negative, add 4294967296 to convert id to hash
						idConversion = knex.raw('(CASE WHEN id < 0 THEN id + 4294967296 ELSE id END) as id, json')
						manifest('DestinyInventoryItemDefinition').select(idConversion).then (rows) ->
							console.log("DB : Inserting data into Manifest table")	   
							knex('manifest').insert(rows)
						.then ->
							console.log("DB : Manifest import complete")
							resolve()

				classLocalizationPromise = new Promise (resolve, reject) ->
					console.log("DB : Clearing old Class localization table")
					knex('classLocalization').delete().then ->
						manifest('DestinyClassDefinition').select().then (rows) ->
							console.log("DB : Inserting data into Class localization table")
							formattedClasses = []

							for currentRow in rows
								currentClass = JSON.parse(currentRow.json)

								insertClass = {}
								insertClass.id = currentClass.hash
								insertClass.name = currentClass.displayProperties.name.toLowerCase()

								formattedClasses.push insertClass

							knex('classLocalization').insert(formattedClasses).then ->
								console.log("DB : Class localization import complete")
								resolve()

				itemStatLocalizationPromise = new Promise (resolve, reject) ->
					console.log("DB : Clearing old Item Stat localization table")
					knex('itemStatLocalization').delete().then ->
						manifest('DestinyStatDefinition').select().then (rows) ->
							console.log("DB : Inserting data into Item Stat localization table")
							formattedStats = []

							for currentRow in rows
								# Certain stats are 'junk', they have no name and must be a back end stat used by the game in some way
								# We insert these stats into the database anyways, so that we don't run into issues with stats
								# not being found in the database
								currentStat = JSON.parse(currentRow.json)

								insertStat = {}
								insertStat.id = currentStat.hash
								insertStat.name = currentStat.displayProperties.name
								
								formattedStats.push insertStat

							knex('itemStatLocalization').insert(formattedStats).then ->
								console.log("DB : Item Stat localization import complete")
								resolve()

				weaponDamageTypeLocalizationPromise = new Promise (resolve, reject) ->
					console.log("DB : Clearing old Weapon Damage Type localization table")
					knex('weaponDamageTypeLocalization').delete().then ->
						manifest('DestinyDamageTypeDefinition').select().then (rows) ->
							console.log("DB : Inserting data into Weapon Damage Type localization table")
							damageTypes = []

							for currentRow in rows
								currentDamageType = JSON.parse(currentRow.json)

								insertDamageType = {}
								insertDamageType.id = currentDamageType.hash
								insertDamageType.name = currentDamageType.displayProperties.name
								
								damageTypes.push insertDamageType

							knex('weaponDamageTypeLocalization').insert(damageTypes).then ->
								console.log("DB : Weapon Damage Type localization import complete")
								resolve()

				Promise.all([manifestPromise, classLocalizationPromise, itemStatLocalizationPromise, weaponDamageTypeLocalizationPromise]).then =>
					@saveSettingToDB("manifest_hash", manifestHash[1]).then ->
						console.log("DB : Manifest loaded into database")
		.catch (error) ->
			console.log("DB : Manifest error")
			console.log(error)
						
	getLocalizedItem: (itemHash) ->
		console.log("DB : Loading item object for item hash (#{itemHash})")

		promise = new Promise (resolve, reject) ->
			knex.where({id: itemHash}).select('json').from('manifest').then (rows) ->
				if rows.length isnt 1
					console.log("DB : Item hash did not return exactly one row")
					reject()
				else
					console.log("DB : Found one row matching item hash")
					resolve(JSON.parse(rows[0].json))

	getLocalizedStat: (statHash) ->
		console.log("DB : Loading stat name for stat hash (#{statHash})")

		promise = new Promise (resolve, reject) ->
			knex.where({id: statHash}).select('name').from('itemStatLocalization').then (rows) ->
				if rows.length isnt 1
					console.log("DB : Stat hash did not return exactly one row (#{statHash})")
					reject()
				else
					console.log("DB : Found one row matching stat hash (#{statHash}:#{rows[0].name})")
					resolve(rows[0].name)

	getLocalizedWeaponDamageType: (weaponDamageTypeHash) ->
		console.log("DB : Loading Weapon Damage Type name for hash (#{weaponDamageTypeHash})")

		promise = new Promise (resolve, reject) ->
			knex.where({id: weaponDamageTypeHash}).select('name').from('weaponDamageTypeLocalization').then (rows) ->
				if rows.length isnt 1
					console.log("DB : Weapon Damage Type hash did not return exactly one row")
					reject()
				else
					console.log("DB : Found one row matching weapon damage type hash")
					resolve(rows[0].name)

	getLocalizedClasses: () ->
		console.log("DB : Loading localized class names")

		knex.select().from('classLocalization').then (rows) ->
			localizedClasses = {}
			
			for row in rows
				localizedClasses[row['name']] = row['id']

			console.log("DB : Loaded localized class names")
			return localizedClasses

	# Plugs are stored in the same table as items, as they are delivered that way from the manifest
	# However we can do some extra processing on them here to clean up anything that is not needed
	getLocalizedPlug: (plugHash) ->
		console.log("DB : Loading plug object for plug hash (#{plugHash})")

		promise = new Promise (resolve, reject) =>
			knex.where({id: plugHash}).select('json').from('manifest').then (rows) =>
				if rows.length isnt 1
					console.log("DB : Plug hash did not return exactly one row")
					reject()
				else
					console.log("DB : Found one row matching plug hash")
					currentPlug = JSON.parse(rows[0].json)

					masterworkPromise = null
					returnPlug = {}
					# This identifiers plugs that are Shaders
					if currentPlug.plug.plugCategoryHash in constants.JUNK_PLUGS
						returnPlug.discard = true
						returnPlug.collapse = false
						returnPlug.name = currentPlug.displayProperties.name
					# This indentifies plugs that are "Intrinsics". Weapon Frames, Exotic perks, etc
					else if currentPlug.plug.plugCategoryHash is 1744546145
						returnPlug.discard = false
						returnPlug.collapse = true
						returnPlug.name = currentPlug.displayProperties.name
					# This filters out a bunch of junk plugs such as Ornaments
					else if currentPlug.itemType in constants.PLUG_TYPES and currentPlug.itemSubType in constants.PLUG_SUBTYPES
						returnPlug.discard = false

						# Check for Masterwork (No easy way to do this other than checking if 'masterwork' is in the plugCategoryIdentifier)
						if currentPlug.plug.plugCategoryIdentifier.includes('masterwork')
							returnPlug.collapse = true
							# Check for v4 Masterwork
							if currentPlug.plug.plugCategoryHash in constants.NEW_MASTERWORK
								# Get the stat name for this masterwork
								masterworkStatHash = currentPlug.investmentStats[0].statTypeHash
								masterworkStatTier = currentPlug.investmentStats[0].value

								masterworkPromise = @getLocalizedStat(masterworkStatHash).then (localizedStatName) ->
									returnPlug.name = "#{localizedStatName} #{masterworkStatTier}"
							# v3 weapon Masterwork
							else if currentPlug.plug.plugCategoryHash in constants.OLD_MASTERWORK
								# Some parts of this tree wont have a stat (Crucible Masterwork, Rework Masterwork, etc)
								if currentPlug.investmentStats.length > 0
									# Get the stat name for this masterwork
									masterworkStatHash = currentPlug.investmentStats[0].statTypeHash
									masterworkStatTier = currentPlug.investmentStats[0].value

									masterworkPromise = @getLocalizedStat(masterworkStatHash).then (localizedStatName) ->
										returnPlug.name = "#{localizedStatName} #{masterworkStatTier}"
								else
									returnPlug.name = currentPlug.displayProperties.name
							else	
								returnPlug.name = currentPlug.displayProperties.name
						# Check for armor or weapon mods
						else if currentPlug.plug.plugCategoryHash in constants.ARMOR_MODS or currentPlug.plug.plugCategoryHash in constants.WEAPON_MODS
							returnPlug.collapse = true
							returnPlug.name = currentPlug.displayProperties.name
						else
							returnPlug.collapse = false
							returnPlug.name = currentPlug.displayProperties.name
					# Junk plug
					else
						returnPlug.discard = true
						returnPlug.collapse = false
						returnPlug.name = currentPlug.displayProperties.name
					
					if masterworkPromise isnt null
						masterworkPromise.then ->
							resolve(returnPlug)
					else
						resolve(returnPlug)

module.exports = GunsmithDatabase