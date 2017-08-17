#Install Guide
add ```deathDrop = require("deathdrop")``` near the top of server.lua *under* ```myMod = require("myMod")```
-- Find "OnPlayerDeath" inside server.lua then put [ deathDrop.OnPlayerDeath(pid, Players[pid], deathReason) ] at the beginning
-- Find "OnPlayerCellChange" inside server.lua then put [ deathDrop.OnPlayerCellChange(pid) ] at the end
-- Find "OnObjectSpawn" inside server.lua then put [ deathDrop.OnObjectSpawn(pid, cellDescription) ] at the end
