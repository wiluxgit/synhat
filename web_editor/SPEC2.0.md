# Structure
The extmodel format is encoded as RGBA of specific pixels on a minecraft 64x64 skin .png image.
More specifically the data is encoded in the top left 8x8 pixels.

Each pixel is decoded into 4 bytes which is used for different purposes.


### What data exists at what pixel coordinates:
```
 X 01234567
Y  ________
0 |G FFFFFF
1 |FFFFFFFF
2 |FFFFTTTT
3 |TTTTTTTT
4 |TTTTTTTT
5 |TTTTTTTT
6 |TTTTTTTT
7 |TTTTTTTT

G: Global Flags
F: Face Operation
T: Transform Data
```

# G (Global Flags)
Global flags describe extmodel properties that apply to the whole model
```c
| R | G | B | A |
|   e   | t | - |
e = Enabled
must be #DA67

t = skin type
Wide (Steve): 0x00
Slim (Alex): 0x01

enabled Steve: #DA6700FF
enabled Alex: #DA6701FF
```
# F (Face Operation)
Face operation describe which (if any) transform should be applied to that face.
Each byte correspongs to one face.

```c
           |         Face operation        |
       bit | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
explnation |F_type |        F_index        |
```

## F_type (Transform type)
```c
switch(T_type) {
    case 0: TRANSFROM_TYPE_displacement;
    case 1: TRANSFROM_TYPE_uv_crop;
    case 2: TRANSFROM_TYPE_uv_offset;
    case 3: TRANSFROM_TYPE_special;
}
```
## F_index (Transform index)
`F_index == 0` ⇒ This face has no transforms
`F_index >= 44` ⇒ Invalid

### Reference C code for getting finding the correct byte given the face ID:
```c
uint8_t getFaceOperationEntry(uint8_t faceid) {
    uint32_t rgba_index = faceId % 4;
    uint32_t F_index = faceId / 4;
    uint32_t x = (F_index + 2) % 8;
    uint32_t y = (F_index + 2) / 8;
    return PIXEL_FETCH(x, y)[rgba_index];
}
```

# T (Transforms)
Transforms constists of `F_type` specific modifier data (T_argument) as well as optional Face operation that should also be applied to the face afterwards.

Each transform uses all 4 bytes of a pixel.

```c
           |       Transform        |
      byte |  R  |  G  |  B  |  A   |
explanation|    T_argument   |T_next|
```

### Reference C code for getting finding the correct RGBA bytes given a F_index
```c
uint32_t getFaceOperation(uint8_t F_index) {
    uint32_t temp = (8*2+4) + F_index;
    uint32_t x = temp % 8;
    uint32_t y = temp / 8;
    return PIXEL_FETCH(x, y);
}
```

## T_arguments
### TRANSFROM_TYPE_DISPLACEMENT
```c
        bit |  R7  |  R6  |  R5  |  R4  |  R3  |  R2  |  R1  |  R0  |
explanation | sign | snap |           global_displacement           |

        bit |  G7  |  G6  |  G5  |  G4  |  G3  |  G2  |  G1  |  G0  |
explanation |a_sign|a_spec|      a_displacement/a_special_mode      |

        bit |  B7  |  B6  |  B5  |  B4  |  B3  |  B2  |  B1  |  B0  |
explanation |                                         |   a_edge    |


sign:
    //Direction of global displacement
    case 0: positive
    case 1: negative

global_displacement:
    // size, (in half pixels) of displacement

snap:
    // if displacement should snap to opposing layer before apply transform
    // Eg: move an outer layer so it lines up with inner layer
    // NOTE: this kinda changes pixel size as well
    case 0: disable
    case 1: enable

// ==============================================
// "a_" stands for assymetric_
// Assymetric Displacement is a displacement that
//   is applied to one edge of a face's vertexes.

a_sign:
    //Direction of assymetric displacement
    case 0: positive
    case 1: negative

a_spec:
    // if a special assymetric transform should be used instead of a_displacement
    case 0: disable
    case 1: enable

a_displacement:
    // size, (in half pixels) of displacement

a_special_mode:
    case 0: ASYMETRIC_SPECIAL_FLIP_OUTER
    case 1: ASYMETRIC_SPECIAL_FLIP_INNER

a_edge:
    // Assymetric Edge: Which edge should be assymtrically transformed
    case 0: top
    case 1: bottom
    case 2: right
    case 3: left
```
### TRANSFROM_TYPE_UV_CROP
```c
        bit |  R7  |  R6  |  R5  |  R4  |  R3  |  R2  |  R1  |  R0  |
explanation |         crop_bot          |         crop_top          |

        bit |  G7  |  G6  |  G5  |  G4  |  G3  |  G2  |  G1  |  G0  |
explanation |         crop_right        |         crop_left         |

        bit |  B7  |  B6  |  B5  |  B4  |  B3  |  B2  |  B1  |  B0  |
explanation |                                         |snap_y|snap_x|

crop_bot / crop_top / crop_right / crop_left:
    // How many pixels to skip rendering that edge

snap_x:
    // Scales and crops the texture width-wise so that pixels are as big as the opposing layers pixels
    // If snapping the primary layer to the secondary this will crop away the left & right most pixels
snap_y:
    // same as snap_x but for height

```
### TRANSFROM_TYPE_UV_OFFSET
```c
        bit |  R7  |  R6  |  R5  |  R4  |  R3  |  R2  |  R1  |  R0  |
explanation |  uv_y_min_0 |                uv_x_max                 |

        bit |  G7  |  G6  |  G5  |  G4  |  G3  |  G2  |  G1  |  G0  |
explanation |  uv_y_min_1 |                uv_x_min                 |

        bit |  B7  |  B6  |  B5  |  B4  |  B3  |  B2  |  B1  |  B0  |
explanation |  uv_y_min_2 |                uv_y_max                 |
```

Reference C code to read/write `uv_y_min`
```c
uint8_t getCropLeft(uint8_t r, uint8_t g, uint8_t b) {
    uint8_t mask = 0b11000000;
    return ((r & mask) >> 2) | ((g & mask) >> 4) | ((b & mask) >> 6);
}
void writeCropLeftToRGB(uint8_t cropLeft, uint8_t* r, uint8_t* g, uint8_t* b) {
    uint8_t mask = 0b11000000;
    *r |= mask & (crop_left << 6);
    *g |= mask & (crop_left << 4);
    *b |= mask & (crop_left << 2);
}
```

### TRANSFROM_TYPE_SPECIAL
```c

| R0 | rainbow

other fields are unused
```