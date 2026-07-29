Pre-work
- Gave claude the context of 2 platformer style games
- Gave it game specs of what i wanted: features, game loop

First pass
- Claude suggested a 'dodge type' based system--i rejected it and wanted collision based
  - Well turns out I hated the collision based feature, snapping back to the position still let you get hit because collision=true
  - Reverted this

At this point i also asked claude to make me a functional architecture map so that I can make edits on my own

7/26
===
Demoed the game to Matt, and there were a few things i noticed
* parrying was instinctually obvious for him
* he never noticed the stamina system i had crafted
* he kept trying to press left multiple times to dodge an arrow (kind of like moving in space) rather than it being a real dodge
* he didn't understand the projectile system (can i dodge the middle one? i don't really get it)

Some insights I got about the core experience
* the core experience is dodging. I need to make that FEEL good before even thinking about moving farther in the game.

action items
* remove stamina from the game
* anchor on some player character
* nail the direction and action i want to player to do