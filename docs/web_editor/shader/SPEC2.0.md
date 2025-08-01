
# Structure
```
pixel coordinate
  01234567
  ________
0|G-FFFFFF
1|FFFFFFFF
2|FFFFTTTT
3|TTTTTTTT
4|TTTTTTTT
5|TTTTTTTT
6|TTTTTTTT
7|TTTTTTTT

G: Global Flags
F: Face Operation[]
T: Transforms[]
```
## Global Flags
```c
G = Global Flags
| R | G | B | A |
|   e   | t | - |
e = Enabled
must be #DA67

t = skin type
Wide (Steve): 0x00
Slim (Alex): 0x01

enabled Steve: #DA670000
enabled Alex: #DA670100
```
## Face Operation
```c
char[72]

F =
|  R  |  G  |  B  |  A  |  R  |  G  |  B  |  A  | ....
| f_0 | f_1 | f_2 | f_3 | f_4 | f_5 | f_6 | f_7 | ....

char getFaceOperationEntry(char faceid) {
    int rgba_index = faceId % 4;
    int F_index = faceId / 4;
    int temp = 2 + F_index
    int x = temp % 8;
    int y = temp / 8;
    return PIXEL_FETCH(x, y)[rgba_index];
}

One f =
| Bit 7 | Bit 6 | Bit 5 | Bit 4 | Bit 3 | Bit 2 | Bit 1 | Bit 0 |
| transform_type |            transform_arugment_index           |
```
### transform_type
```c
switch(transform_type) {
    case 0:
        return TRANSFROM_TYPE_displacement;
    case 1:
        return TRANSFROM_TYPE_uv_crop;
    case 2:
        return TRANSFROM_TYPE_uv_offset;
    case 3:
        return TRANSFROM_TYPE_special;
}
```
### transform_arugment_index
`transform_arugment_index == 0` ⇒ This Face Is Disabled *(Has No Transform)*
`transform_arugment_index >= 44` ⇒ Invalid

## Transforms
A Linked List of `(Transform Type, Memory Index Of Transform Arguments)`
```c
uint32[44]

T[0] =
|  R  |  G  |  B  |  A   |
|    arguments    | next |

int getFaceOperation(char transform_arugment_index) {
    int temp = (8*2+4) + transform_arugment_index;
    int x = temp % 8;
    int y = temp / 8;
    return PIXEL_FETCH(x, y);
}
```
arguments
```c
case TRANSFROM_TYPE_DISPLACEMENT
|  R7  |  R6  |  R5  |  R4  |  R3  |  R2  |  R1  |  R0  |
| sign | snap |           global_displacement           |

|  G7  |  G6  |  G5  |  G4  |  G3  |  G2  |  G1  |  G0  |
|a_sign|a_spec|      a_displacement/a_special_mode      |

|  B7  |  B6  |  B5  |  B4  |  B3  |  B2  |  B1  |  B0  |
|                                         |   a_edge    |


sign:
    //Direction of global displacement
    case 0: positive
    case 1: negative

global_displacement:
    // size, (in pixels*) of displacement

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
    // size, (in pixels*) of displacement

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
```c
case TRANSFROM_TYPE_UV_CROP
|  R7  |  R6  |  R5  |  R4  |  R3  |  R2  |  R1  |  R0  |
|         crop_bot          |         crop_top          |

|  G7  |  G6  |  G5  |  G4  |  G3  |  G2  |  G1  |  G0  |
|         crop_right        |         crop_left         |

|  B7  |  B6  |  B5  |  B4  |  B3  |  B2  |  B1  |  B0  |
|                                         |snap_y|snap_x|
crop_"X":
    // How many pixels to skip rendering from edge "X"

snap_:
    // scales and crops the texture so that pixels are as big as the opposing layers pixels
    // /!\ For it to allign correctly on primary layer you need a TRANSFROM_TYPE_UV_OFFSET
    //     that is 2 pixels smaller in the snap direction than the secondary layer
snap_x: // width
snap_y: // height

```
```c
case TRANSFROM_TYPE_UV_OFFSET
|  R7  |  R6  |  R5  |  R4  |  R3  |  R2  |  R1  |  R0  |
|  uv_y_min_0 |                uv_x_max                 |

|  G7  |  G6  |  G5  |  G4  |  G3  |  G2  |  G1  |  G0  |
|  uv_y_min_1 |                uv_x_min                 |

|  B7  |  B6  |  B5  |  B4  |  B3  |  B2  |  B1  |  B0  |
|  uv_y_min_2 |                uv_y_max                 |

// to extract uv_y_min
char getCropLeft(char r, char g, char b) {
    char mask = 0b11000000;
    return ((r & mask) >> 2) | ((g & mask) >> 4) | ((b & mask) >> 6);
}
void writeCropLeftToRGB(char crop_left, char* r, char* g, char* b) {
    char mask = 0b11000000;
    *r |= mask & (crop_left << 6);
    *g |= mask & (crop_left << 4);
    *b |= mask & (crop_left << 2);
}
```

```c
case TRANSFROM_TYPE_SPECIAL

| R0 | rainbow

other fields are unused
```