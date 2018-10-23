# Gunsmith
 
Gunsmith is a Slack bot based on the [Hubot](https://hubot.github.com/) framework, and heavily influenced by [phillipspc's Showoff](https://github.com/phillipspc/showoff).
 
With the release of the Forsaken expansion, random items are back. That means that you probably want people to weigh in on your roll or show off your perfect roll!
 
Gunsmith is designed to make it easy for users to show off their Destiny 2 items in Slack with as few inputs as possible. 
 
### Usage
 
Gunsmith only requires at most 4 inputs, directed at the bot (order does not matter): 
* Xbox Live GamerTag/PlayStation Network username/Battle.net username
* Gaming platform ("Xbox", "PlayStation", or "PC")
* Character class ("Hunter", "Titan", "Warlock")
* Item slot ("primary", "special", "heavy" and if armor is enabled, "head", "chest", "arms", "legs", "class", "ghost")
 
The standard usage looks like this: 
`@Gunsmith MyGamertag xbox hunter primary`
 
with a response looking like (active nodes in bold): 
![image](https://user-images.githubusercontent.com/24279336/47389538-097e6a00-d6e3-11e8-8285-260d135801cb.png) 
 
### Advanced Options
If you set the `default_platform` setting, you can omit it in your request.  
`@Gunsmith MyGamertag hunter primary`
 
If your Slack profile's **first name** (not username) matches your gaming platform username, you can omit it as well.  
`@Gunsmith xbox hunter primary`
 
If you omit the character class, Gunsmith will default to the most recently played character.  
`@Gunsmith MyGamertag xbox primary`
 
Combining these options, you can very easily activate the bot with as little as one input.  
`@Gunsmith primary`
 
Note that inputs override defaults. So if `default_platform` is set to `xbox` and a request contains `pc` in the input, the Gunsmith will check the `pc` platform.  
This also applies to platform usernames.

### Setting up the bot in your own Slack
 
Note: Gunsmith needs a PostgreSQL database to store localized info from the Destiny 2 Manifest. The Heroku free tier of PostgreSQL is limited to 10,000 rows, of which Gunsmith uses around 8,000.  
This means that if you already have other Heroku applications using PostgreSQL, you may run out of space in your free database.
 
Install [Heroku Toolbelt](https://toolbelt.heroku.com/)  
Install [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)  

Clone the repo locally:  
`git clone git@github.com:xxbiohazrdxx/gunsmith.git`
 
Deploy to heroku, `cd` into the newly created folder then follow these steps:
- `heroku create my-new-slackbot`
- `heroku addons:create heroku-postgresql:hobby-dev`
- `git push heroku master`
 
[Get a Slack token](http://my.slack.com/services/new/hubot) to allow Gunsmith to communicate with your Slack workspace.  
[Get a Bungie API key](https://www.bungie.net/en/Application) to allow Gunsmith to query the Bungie API.  
 
Set the following [configuration variables](https://devcenter.heroku.com/articles/config-vars):  
- `HUBOT_SLACK_TOKEN=your-slack-token-here`  
- `BUNGIE_API_KEY=your-bungie-key-here`. 
 
There should also be two automatically created configuration variables, they should be left alone.
- `HEROKU_URL` The URL to your Heroku dyno, used for keeping the Gunsmith awake.  
- `DATABASE_URL` The URL to your PostgreSQL database, used for connecting to the database.
 
Note: Free Heroku dynos are limited to 550 hours per month, meaning that eventually your Gunsmith bot will suspended before the month is out. You may, if you so desire, get an additional 450 dyno hours by adding a valid credit card to Heroku.

Once the Gunsmith is online and connected to your Slack workspace, issue a `manifest` command to it via a direct message to kick off the initial Manifest data import.
 
### Configuring the Gunsmith
 
Certain Gunsmith settings can be changed directly through Slack by sending a direct message in the format:  
`config <setting name> <setting value>`
 
Valid settings are:  
`show_armor` - Sets whether the Gunsmith will respond and display armor, in addition to weapons. Accepts values `true` or `false`. Defaults to `true`.  
`allow_admin_config` - Sets whether the Gunsmith will allow anyone who is a Slack admit to access the configure commands. Accepts values `true` or `false`. Defaults to `true`.  
`owner_id` - Sets the owner of the Gunsmith (That's you!). The owner is always able to configure the bot, even if `allow_admin_config` is set to `false`. Accepts any string as a value. Defaults to empty.  
`default_platform` - Sets the default gaming platform for your Slack. Useful if all of most users are on one platform. Accepts `xbox`, `playstation`, or `pc` as a value. Defaults to empty.  
`longform_output` - Sets whether the Gunsmith will output all useful weapon perks (`true`), or only activated weapon perks (`false`). Accepts values `true` or `false`. Defaults to `true`.  
`language` - Sets the Gunsmith language. Destiny 2 is localized for multiple languages, and as such the Gunsmith is capable of outputting items in any supported Langauge. Accepts values:
- `en` (English)
- `fr` (French)
- `es` (Spanish)
- `de` (German)
- `it` (Italian)
- `ja` (Japanese)
- `pt-br` (Portugese - Brazil)
- `es-mx` (Spanish - Mexico)
- `ru` (Russian)
- `pl` (Polish)
- `zh-cht` (Chinese - Traditional).

Defaults to `en` (English). Note that changing the language automatically starts a Manifest update.

### Updating the Manifest

The Destiny 2 Manifest is a database that contains localized information about items, perks, stats, classes, etc. and is required for producing readable output. Because of this, keeping the Manifest up to date is essential to the Gunsmith being able to understand the items it is trying to output to the user.

Whenever Destiny 2 is updated, you should update the Manifest. To do so, simply direct message the Gunsmith the command:  
`manifest`

The update process generally takes less than one minute.

As with configuration changes, this can only be done by the owner or a Slack administrator (if `allow_admin_config` is enabled).
 
### How can I help?
 
Localization!
 
While the Destiny 2 Manifest has localized item names, perk names, stat names, etc. The Gunsmith itself is written by an English speaker.
 
Localization in all languages is needed for the following:
- Gunsmith response strings (located in `strings.coffee`).
- Gunsmith item slots (located in `constants.coffee`)
- Gaming network names (located in `constants.coffee`)
 
I've provided some basic translations of response strings by using internet based translators, but they're far from ideal. However, item slots (primary, secondary, heavy, etc.) and gaming networks (xbox, playstation, pc, etc.) are so varied in how they can be requested, translating them in this manner is incredibly difficult.
 
If you are native or fluent speaker of a language that is supported by Destiny 2, a few minutes of your time could be incredibly valuable!
