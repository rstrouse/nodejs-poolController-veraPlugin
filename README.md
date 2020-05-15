# nodejs-poolController-veraPlugin
## License
NodeJS Pool Controller Plugin
Copyright (C) 2020 Robert Strouse
 
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
 

## What is nodejs-poolController-veraPlugin
This is a plugin that interacts with an installed nodejs-poolController server to provide automation and control for your Vera home automation hub.  The nodejs-poolController server allows you to control Pentair pool equipment via its RS485 port.  This includes outdoor control panels for IntelliCenter, IntelliTouch, and EasyTouch.  It also includes a standalone function that allows you to control pumps and chlorinators without an automation controller.

You can find [nodejs-poolController here](https://github.com/tagyoureit/nodejs-poolController/tree/next).

NOTE: This plugin does not work with version 5 or below.  You must install version 6.x and above.

To install the plugin follow the instructions in the [Installation and Setup](https://github.com/rstrouse/nodejs-poolController-veraPlugin/wiki/Installation-and-Setup) wiki.

## What nodejs-poolController-veraPlugin Does
It provides automation support through your Vera hub and acts as yet another controller for your pool equipment.  It is capable of integrating with scenes and other devices on your Vera.  Every device that is connected to the nodejs-poolController server can be automated and controlled with Vera.  All status information is instant and reflected immediately.
![veraDevices](https://user-images.githubusercontent.com/47839015/82096538-0cbabb80-96b6-11ea-8004-34085088c19d.png)

