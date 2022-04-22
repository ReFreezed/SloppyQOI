**SloppyQOI** is a small [QOI](https://qoiformat.org/) image format encoder and decoder library for the [LÖVE](https://love2d.org/) game framework.

[The library](https://raw.githubusercontent.com/ReFreezed/SloppyQOI/master/qoi.lua) is a single file with no external dependencies other than LÖVE.
[MIT license](LICENSE.txt).

See the top of [qoi.lua](https://raw.githubusercontent.com/ReFreezed/SloppyQOI/master/qoi.lua) for documentation.

I mostly just made this for fun.
I'm not sure anyone should actually use QOI instead of PNG, at least not for textures in games (see below).


## Some stats

Running the library on the 2848 images in [qoi_benchmark_suite.tar](https://qoiformat.org/benchmark/) on my crappy computer reveals:

- Decoding QOI files is on average 5% faster than [decoding PNGs](https://love2d.org/wiki/love.image.newImageData).
- Encoding QOI files is on average 25% faster than [encoding PNGs](https://love2d.org/wiki/ImageData:encode).
- QOI files are on average 80% larger than (optimized) PNGs.

You gain some, you lose some, I guess...

