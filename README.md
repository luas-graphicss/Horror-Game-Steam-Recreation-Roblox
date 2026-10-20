# Horror Game Steam Recreation

[Leia em português](README.pt-BR.md)

A recreation inside Roblox of an industrial horror game from Steam. You play as a worker in a strange factory, doing your shift while trying to pay off a debt, and little by little you realize the place is not normal.

The work itself is the heart of the game. You tighten bolts on a conveyor, charge a crank generator, feed the grinder and keep production going, earning money to buy tools and upgrades in the shop and to hire employees. The phone rings with calls that push the story forward, sector doors open new areas and there are eyes growing out of the walls that you have to pry out with a crowbar. Characters like Tromby and the Tromby Watcher show up along the way, talk to you and vanish, and the story has its own ending.

The project has a main menu, settings, subtitles for the spoken lines, a tool hotbar, jumpscares and automatic saving. The server code is split by system, the Shared folder keeps all the configuration and the client takes care of the interactions, the visuals and the interface. The ServerStorage folder also carries the ImportMCP plugin and the pipeline I used to import and build the second sector of the map.

This is a fan recreation made for study and has no connection with the original developers.

## How to use

Each folder at the root matches a Roblox service, such as Workspace, ReplicatedStorage, ServerScriptService, ServerStorage, StarterGui and StarterPlayer. Bring the folders into an empty place keeping the same structure, using Rojo or another sync tool, and press Play in Studio. If you want progress to save while testing in Studio, turn on access to API services in the game settings.

## Development time

The game was built in a single day.

## License

GNU General Public License version 3. The full text is in the LICENSE file.
