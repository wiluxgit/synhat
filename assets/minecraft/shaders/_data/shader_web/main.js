let uploadInputImage = document.getElementById('uploadInputImage')
let canvasSkinPreview = document.getElementById('canvasSkinPreview')
let canvasSkinPreviewCtx = canvasSkinPreview.getContext('2d')

MAIN = {}
MAIN.changedUploadImage = (inputEvent) => {
    let reader = new FileReader()
    reader.onload = (e) => {
        var img = new Image()
        img.onload = () => {
            if (!(img.width == 64 && img.height == 64)) {
                alert('Image is not 64x64')
            }
            canvasSkinPreviewCtx.clearRect(0, 0, canvasSkinPreview.width, canvasSkinPreview.height);
            canvasSkinPreviewCtx.drawImage(img, 0, 0)
        }
        img.src = e.target.result
    }
    reader.readAsDataURL(inputEvent.target.files[0]);
}

MAIN.resetSelectedSkin = () => {
    var img = new Image()
    img.src = "assets/steve.png"
    uploadInputImage.value = ""
    img.onload = () => {
        canvasSkinPreviewCtx.clearRect(0, 0, canvasSkinPreview.width, canvasSkinPreview.height);
        canvasSkinPreviewCtx.drawImage(img, 0, 0)
    }
}

MAIN.debugAllTransforms = (content) => {
    for (faceTransfrom of content){
        let parser = MAIN.transform_parsers[faceTransfrom.type];
        let buf = parser.encode(faceTransfrom.data);

        binStr = [...buf].map((b) => b.toString(2).padStart(8, "0")).join(" ");
        hexStr = buf.toString("hex")
        console.log(`0b${binStr} | 0x${hexStr}`);

        let parsres = parser.parse(buf)
        console.log(parsres)
    }
}

MAIN.enums = {
    transform_type:{
        displacement: 0,
        uv_offset: 1,
        uv_crop: 2,
        special: 3,
    },

    snap: {
        true: 1,
        false: 0,
    },

    sign: {
        positive: 0,
        negative: 1,
    },

    asym_spec: {
        no: 0,
        yes: 1,
    },

    asym_sign: {
        positive: 0,
        negative: 1,
    },

    asym_special_mode:{
        flip_outer: 0,
        flip_inner: 1,
    },

    asym_edge: {
        top: 0,
        bottom: 1,
        right: 2,
        left: 3,
    },
}

MAIN.faceOperationParser = (
    new BinaryParser.Parser()
        .endianess("little")
        .encoderSetOptions({bitEndianess: true})
        .bit2("transform_type")
        .bit6("transform_argument_index")
)

MAIN.default_transform = {}
MAIN.transform_parsers = {}
// ====================================================
MAIN.transform_parsers[MAIN.enums.transform_type.displacement] = (
    new BinaryParser.Parser()
        .endianess("little")
        .encoderSetOptions({bitEndianess: true})
        .bit6("global_displacement")
        .bit1("snap")
        .bit1("sign")
        .bit6("asym_displacement")
        .bit1("asym_sign")
        .bit1("asym_spec")
        .bit2("asym_edge")
        .bit6("__filler__")
        .bit8("next")
)
MAIN.default_transform[MAIN.enums.transform_type.displacement] = {
    global_displacement: 0,
    snap: MAIN.enums.snap.true,
    sign: MAIN.enums.sign.positive,
    asym_displacement: 0,
    asym_sign: MAIN.enums.asym_sign.positive,
    asym_spec: MAIN.enums.asym_spec.no,
    asym_edge: MAIN.enums.asym_edge.top,
}

// ====================================================
MAIN.transform_parsers[MAIN.enums.transform_type.uv_offset] = (
    new BinaryParser.Parser()
        .endianess("little")
        .encoderSetOptions({bitEndianess: true})
        .bit6("uv_x_max")
        .bit2("uv_y_min_0")
        .bit6("uv_x_min")
        .bit2("uv_y_min_1")
        .bit6("uv_y_max")
        .bit2("uv_y_min_2")
)
MAIN.default_transform[MAIN.enums.transform_type.uv_offset] = {
    uv_x_max: 0,
    uv_x_min: 0,
    uv_y_max: 0,
    uv_y_min_0: 0,
    uv_y_min_1: 0,
    uv_y_min_2: 0,
}

// ====================================================
MAIN.transform_parsers[MAIN.enums.transform_type.uv_crop] = (
    new BinaryParser.Parser()
        .endianess("little")
        .encoderSetOptions({bitEndianess: true})
        .bit6("crop_top")
        .bit2("crop_bot")
        .bit6("crop_right")
        .bit2("crop_left_0")
        .bit6("crop_left_1")
        .bit2("crop_left_2")
)
MAIN.default_transform[MAIN.enums.transform_type.uv_crop] = {
    crop_top: 0,
    crop_bot: 0,
    crop_right: 0,
    crop_left_0: 0,
    crop_left_1: 0,
    crop_left_2: 0,
}

// ====================================================
MAIN.transform_parsers[MAIN.enums.transform_type.special] = (
    new BinaryParser.Parser()
        .endianess("little")
        .encoderSetOptions({bitEndianess: true})
        .bit1("top_snap_clip_uv")
        .bit1("bot_snap_clip_uv")
        .bit1("right_snap_clip_uv")
        .bit1("left_snap_clip_uv")
        .bit4("__filler__")
        .bit8("__filler2__")
        .bit8("__filler3__")
        .bit8("__filler4__")
)
MAIN.default_transform[MAIN.enums.transform_type.special] = {
    top_snap_clip_uv: 0,
    bot_snap_clip_uv: 0,
    left_snap_clip_uv: 0,
    right_snap_clip_uv: 0,
}

MAIN.MakeExprToCreateSignedTwoWayBinding = (signedDotPath, absDotPath, isNegativeDotPath) => {
    return `
    $watch(\"${signedDotPath}\", (value) => {
        if (${signedDotPath}) {
            ${absDotPath} = Math.abs(${signedDotPath})
            ${isNegativeDotPath} = ${signedDotPath} < 0
        }
    })
    $watch(\"${absDotPath}\", (value) => {
        if (${signedDotPath}) {
            ${signedDotPath} = ${absDotPath} * (${isNegativeDotPath} ? -1 : 1)
        }
    })
    $watch(\"${isNegativeDotPath}\", (value) => {
        if (${signedDotPath}) {
            ${signedDotPath} = ${absDotPath} * (${isNegativeDotPath} ? -1 : 1)
        }
    })
    ${signedDotPath} = ${absDotPath} * (${isNegativeDotPath} ? -1 : 1)
    `
}

MAIN.id2uvs = {
    0: [[16, 8], [24, 16]],
    6: [[28, 20], [32, 32]],
    12: [[40, 52], [44, 64]],
    18: [[48, 20], [52, 32]],
    24: [[24, 52], [28, 64]],
    30: [[8, 20], [12, 32]],
    36: [[48, 8], [56, 16]],
    42: [[8, 36], [12, 48]],
    48: [[8, 52], [12, 64]],
    54: [[56, 52], [60, 64]],
    60: [[48, 36], [52, 48]],
    66: [[28, 36], [32, 48]],
    1: [[0, 8], [8, 16]],
    7: [[16, 20], [20, 32]],
    13: [[32, 52], [36, 64]],
    19: [[40, 20], [44, 32]],
    25: [[16, 52], [20, 64]],
    31: [[0, 20], [4, 32]],
    37: [[32, 8], [40, 16]],
    43: [[0, 36], [4, 48]],
    49: [[0, 52], [4, 64]],
    55: [[48, 52], [52, 64]],
    61: [[40, 36], [44, 48]],
    67: [[16, 36], [20, 48]],
    2: [[8, 0], [16, 8]],
    8: [[20, 16], [28, 20]],
    14: [[36, 48], [40, 52]],
    20: [[44, 16], [48, 20]],
    26: [[20, 48], [24, 52]],
    32: [[4, 16], [8, 20]],
    38: [[40, 0], [48, 8]],
    44: [[4, 32], [8, 36]],
    50: [[4, 48], [8, 52]],
    56: [[52, 48], [56, 52]],
    62: [[44, 32], [48, 36]],
    68: [[20, 32], [28, 36]],
    3: [[16, 0], [24, 8]],
    9: [[28, 16], [36, 20]],
    15: [[40, 48], [44, 52]],
    21: [[48, 16], [52, 20]],
    27: [[24, 48], [28, 52]],
    33: [[8, 16], [12, 20]],
    39: [[48, 0], [56, 8]],
    45: [[8, 32], [12, 36]],
    51: [[8, 48], [12, 52]],
    57: [[56, 48], [60, 52]],
    63: [[48, 32], [52, 36]],
    69: [[28, 32], [36, 36]],
    4: [[8, 8], [16, 16]],
    10: [[20, 20], [28, 32]],
    16: [[36, 52], [40, 64]],
    22: [[44, 20], [48, 32]],
    28: [[20, 52], [24, 64]],
    34: [[4, 20], [8, 32]],
    40: [[40, 8], [48, 16]],
    46: [[4, 36], [8, 48]],
    52: [[4, 52], [8, 64]],
    58: [[52, 52], [56, 64]],
    64: [[44, 36], [48, 48]],
    70: [[20, 36], [28, 48]],
    5: [[24, 8], [32, 16]],
    11: [[32, 20], [40, 32]],
    17: [[44, 52], [48, 64]],
    23: [[52, 20], [56, 32]],
    29: [[28, 52], [32, 64]],
    35: [[12, 20], [16, 32]],
    41: [[56, 8], [64, 16]],
    47: [[12, 36], [16, 48]],
    53: [[12, 52], [16, 64]],
    59: [[60, 52], [64, 64]],
    65: [[52, 36], [56, 48]],
    71: [[32, 36], [40, 48]],
}