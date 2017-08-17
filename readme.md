# Install Guide

**1.)** add: ```deathDrop = require("deathdrop")``` 
*near the top* of **server.lua** *under* ```myMod = require("myMod")```


**2.)** CTRL+F and find ```OnPlayerDeath``` inside **server.lua** then put ```deathDrop.OnPlayerDeath(pid)``` at the *beginning* of that block


**3.)** CTRL+F and find ```OnPlayerCellChange``` inside **server.lua** then put ```deathDrop.OnPlayerCellChange(pid)``` at the *end* of that block


**4.)** CTRL+F and find ```OnObjectSpawn``` inside **server.lua** then put ```deathDrop.OnObjectSpawn(pid, cellDescription)``` at the *end* of that block
