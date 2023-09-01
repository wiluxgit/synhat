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