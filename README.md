# SloppyQOI

[![](https://img.shields.io/github/release/ReFreezed/SloppyQOI.svg)](https://github.com/ReFreezed/SloppyQOI/releases/latest)
[![](https://img.shields.io/github/license/ReFreezed/SloppyQOI.svg)](https://github.com/ReFreezed/SloppyQOI/blob/master/LICENSE.txt)

**SloppyQOI** is a small [QOI](https://qoiformat.org/) image format encoder and decoder library for the [LÖVE](https://love2d.org/) game framework.
[The library](https://raw.githubusercontent.com/ReFreezed/SloppyQOI/master/qoi.lua) is a single file with no external dependencies other than LÖVE.
[MIT license](LICENSE.txt).

I mostly just made this for fun, but it seems using QOI and this library actually may be beneficial.



## Usage

```lua
local qoi         = require("qoi")
local playerImage = qoi.load("images/player.qoi")
love.graphics.draw(playerImage)
```

See the top of [qoi.lua](https://raw.githubusercontent.com/ReFreezed/SloppyQOI/master/qoi.lua) for documentation.



## Stats

Running the library on the 2848 images in [qoi_benchmark_suite.tar](https://qoiformat.org/benchmark/) (on my crappy computer) reveals these things:

- Both decoding and encoding QOI files is for the most part a fair bit faster than [decoding](https://love2d.org/wiki/love.image.newImageData) and [encoding](https://love2d.org/wiki/ImageData:encode) PNGs.
- QOI files are mostly somewhere between 0 and 1 times larger than (optimized) PNGs, but sometimes a lot more.

Not perfect, but not bad!


