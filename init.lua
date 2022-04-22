-- Require qoi.lua from the same folder.
return require(((".".. ...):gsub("%.init$", "")..".qoi"):sub(2))
