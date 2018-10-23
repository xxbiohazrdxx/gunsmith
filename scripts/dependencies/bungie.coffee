Promise = require('promise')
require('dotenv').load()
Traveler = require('the-traveler').default
{ComponentType} = require('the-traveler/build/enums')

class BungieAPI
	constructor: () ->
		@apiKey = process.env.BUNGIE_API_KEY

	getEquippedItem: (platform, playerUsername, classHash, slotHash) ->
		promise = new Promise (resolve, reject) =>
			console.log("API : Searching for player (#{playerUsername})")
			traveler = new Traveler apikey: @apiKey, userAgent: "GunsmithBot"
			traveler.searchDestinyPlayer(platform, playerUsername).then (foundPlayer) ->
				playerId = foundPlayer.Response[0].membershipId

				console.log("API : Searching for characters of player (#{playerId})")
				traveler.getProfile(platform, playerId, {components: [ComponentType.Characters]}).then (foundCharacters) =>
					allCharacters = foundCharacters.Response.characters.data
					Keys = Object.keys(allCharacters)

					# If no character is specified, use the last played character by checking the last played date
					if not classHash?
						console.log('API : No character specified. Using most recent character.')
						mostRecentCharacterId = Keys.reduce((a, b) ->
							return if Date.parse(allCharacters[a].dateLastPlayed) > Date.parse(allCharacters[b].dateLastPlayed) then a else b)
						character = allCharacters[mostRecentCharacterId]
					# Otherwise, use the specified character
					else
						# Check the returned characters, trying to find if any of them inputs is the one specified
						console.log('API : Character specified. Attempting to locate characterId')	

						matchedCharacterKeys = Keys.filter((object) ->
							"#{allCharacters[object].classHash}" is classHash)
						
						if matchedCharacterKeys.length is 0
							console.log("API : No matching class detected")
							reject("NO_CLASS_FOUND_ERROR")
						else if matchedCharacterKeys.length > 1
							console.log("API : Duplicate class detected")
							reject("DUPLICATE_CLASS_ERROR")

						character = allCharacters[matchedCharacterKeys[0]]

					characterId = character.characterId

					console.log("API : Searching for equipment of character (#{characterId})")
					traveler.getCharacter(platform, playerId, characterId, {components: [ComponentType.CharacterEquipment]}).then (foundEquipment) ->
						allEquipment = foundEquipment.Response.equipment.data.items
						
						allEquipment = allEquipment.filter((object) ->
							"#{object.bucketHash}" is "#{slotHash}")
						
						if allEquipment.length is 0
							console.log("API : No items found in specified slot")
							reject("ITEM_NOT_FOUND_ERROR")
						
						itemInstanceId = allEquipment[0].itemInstanceId
						
						console.log("API : Searching for instance of item (#{itemInstanceId})")
						traveler.getItem(platform, playerId, itemInstanceId, {components: [ComponentType.ItemCommonData, ComponentType.ItemStats, ComponentType.ItemSockets, ComponentType.ItemInstances]}).then (foundItem) ->
							resolve(foundItem.Response)

module.exports = BungieAPI