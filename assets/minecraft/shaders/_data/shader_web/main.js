(() => {
  let uploadInputImage = document.getElementById('uploadInputImage')
  let canvasSkinPreview = document.getElementById('canvasSkinPreview')
  let canvasSkinPreviewCtx = canvasSkinPreview.getContext('2d')

  window.main = {
    changedUploadImage(inputEvent) {
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
    },

    resetSelectedSkin() {
      var img = new Image()
      img.src = "assets/steve.png"
      uploadInputImage.value = ""
      img.onload = () => {
        canvasSkinPreviewCtx.clearRect(0, 0, canvasSkinPreview.width, canvasSkinPreview.height);
        canvasSkinPreviewCtx.drawImage(img, 0, 0)
      }
    },

    applyJsonToTexture() {

    },
  }
})()