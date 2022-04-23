# SloppyQOI

**SloppyQOI** is a small [QOI](https://qoiformat.org/) image format encoder and decoder library for the [LÖVE](https://love2d.org/) game framework.
[The library](https://raw.githubusercontent.com/ReFreezed/SloppyQOI/master/qoi.lua) is a single file with no external dependencies other than LÖVE.
[MIT license](LICENSE.txt).

I mostly just made this for fun.
I'm not sure anyone should actually use QOI instead of PNG - at least not for textures in games, or with this library (see stats below).



## Usage

```lua
local qoi         = require"qoi"
local playerImage = love.graphics.newImage(qoi.read"images/player.qoi")
```

See the top of [qoi.lua](https://raw.githubusercontent.com/ReFreezed/SloppyQOI/master/qoi.lua) for documentation.



## Stats

Running the library on the 2848 images in [qoi_benchmark_suite.tar](https://qoiformat.org/benchmark/) (on my crappy computer) reveals these things:

- Decoding QOI files is often faster, but other times slower, than [decoding PNGs](https://love2d.org/wiki/love.image.newImageData).
- Encoding QOI files is for the most part decently faster than [encoding PNGs](https://love2d.org/wiki/ImageData:encode).
- QOI files are mostly somewhere between 0 and 1 times larger than (optimized) PNGs, but sometimes a lot more.

Win some, lose some, I guess...


