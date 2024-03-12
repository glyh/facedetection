import system

import os
import math
import stb_image/read as stbi
import stb_image/write as stbw

{.passC: "-I" & currentSourcePath().parentDir() .}

{.compile: "facedetectcnn.cpp" .}
{.compile: "facedetectcnn-data.cpp" .}
{.compile: "facedetectcnn-model.cpp" .}

proc facedetect_cnn*(
  result_buffer: ptr uint8, 
  rgb_image_data: ptr uint8, 
  width: cint, 
  height: cint, 
  step: cint
): ptr cint {.
  importcpp: "facedetect_cnn(@)", 
  header: "facedetectcnn.h"
.}

template ptrMath*(body: untyped) =
  template `+`[T](p: ptr T, off: int): ptr T =
    cast[ptr type(p[])](cast[uint](p) + off * sizeof(p[]))
  
  template `+=`[T](p: ptr T, off: int) =
    p = p + off
  
  template `-`[T](p: ptr T, off: int): ptr T =
    cast[ptr type(p[])](cast[uint](p) - off * sizeof(p[]))
  
  template `-=`[T](p: ptr T, off: int) =
    p = p - off
  
  template `[]`[T](p: ptr T, off: int): T =
    (p + off)[]
  
  template `[]=`[T](p: ptr T, off: int, val: T) =
    (p + off)[] = val
  
  body

type DetectResult = tuple[confidence: int, x: int, y: int, w: int, h: int]
proc detectFaces*(filePath: string): seq[DetectResult] = 
  var
    width, height, channels: int
    data: seq[uint8]
  data = stbi.load(filePath, width, height, channels, stbi.RGB)
  var idx = 0
  # RGB to BGR convertion
  while idx < width * height:
    swap(data[idx * 3], data[idx * 3 + 2])
    idx += 1
  let pBuffer = alloc(0x20000)
  var pResult: ptr cint =
    facedetect_cnn(
      cast[ptr uint8](pBuffer), 
      cast[ptr uint8](addr(data[0])), 
      cast[cint](width), 
      cast[cint](height), 
      cast[cint](width * 3)
    )
  let numberMatches = pResult[]
  var ret: seq[DetectResult] = @[]
  var numberProcessed = 0 
  ptrMath:
    var baseAddr = cast[ptr cshort](pResult + 1)
    while numberProcessed < numberMatches:
      ret.add((
          confidence: cast[int](baseAddr[0]),
          x: cast[int](baseAddr[1]),
          y: cast[int](baseAddr[2]),
          w: cast[int](baseAddr[3]),
          h: cast[int](baseAddr[4]),
      ))
      numberProcessed += 1
      baseAddr += 16
  return ret

if isMainModule:
  echo detectFaces("a.jpg")

