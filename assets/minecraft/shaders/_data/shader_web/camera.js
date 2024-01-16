'use strict';

import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { OBJLoader } from 'three/addons/loaders/OBJLoader.js';
import * as twgl from 'twgl';

async function main() {
  const modelCanvas = document.getElementById("camera");
  const previewCanvas = document.getElementById("canvasSkinPreview")

  const modelRenderer = new THREE.WebGLRenderer({canvas: modelCanvas});

  const glModel = modelRenderer.getContext("webgl2")
  const glPreview = previewCanvas.getContext("webgl2")
  const glModelTexture = glModel.createTexture()
  const glPreviewTexture = glPreview.createTexture()

  // ONLY USE FOR WEBGL CONSTANTS
  const gl = glModel

  // Init textures
  {
    var raw = new Uint8ClampedArray(64*64*4)
    raw.fill(200)
    const imageData = new ImageData(raw, 64,64)
    createImageBitmap(imageData).then((imageBitmap) => {
      // Preview view
      const vs = `
        attribute vec4 position;
        void main() {
          gl_PointSize = 64.0;
          gl_Position = position;
        }`;
      const fs = `
        precision mediump float;
        uniform sampler2D tex;
        void main() {
          gl_FragColor = texture2D(tex, gl_PointCoord);
        }`;
      const program = twgl.createProgram(glPreview, [vs, fs]);
      glPreview.useProgram(program);

      glPreview.pixelStorei(gl.UNPACK_COLORSPACE_CONVERSION_WEBGL, gl.NONE)
      glPreview.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true)
      glPreview.bindTexture(gl.TEXTURE_2D, glPreviewTexture);
      glPreview.texImage2D(
        gl.TEXTURE_2D, 0, gl.RGBA, 64, 64, 0,
        gl.RGBA, gl.UNSIGNED_BYTE,
        imageBitmap
      )
      glPreview.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
      glPreview.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      glPreview.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      glPreview.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

      // Camera view
      glModel.pixelStorei(gl.UNPACK_COLORSPACE_CONVERSION_WEBGL, gl.NONE)
      glModel.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true)
      glModel.bindTexture(gl.TEXTURE_2D, glModelTexture);
      // glModel.texImage2D(
      //   gl.TEXTURE_2D, 0, gl.RGBA, 64, 64, 0,
      //   gl.RGBA, gl.UNSIGNED_BYTE,
      //   imageBitmap
      // )
      glModel.generateMipmap(gl.TEXTURE_2D);
      glModel.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
      glModel.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
      glModel.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      glModel.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    });
  }

  const fov = 45;
  const aspect = 2;  // the canvas default
  const near = 0.1;
  const far = 100;
  const camera = new THREE.PerspectiveCamera(fov, aspect, near, far);
  camera.position.set(0, 10, 20);

  const controls = new OrbitControls(camera, modelCanvas);
  controls.target.set(0, 5, 0);
  controls.update();

  const scene = new THREE.Scene();
  scene.background = new THREE.Color('black');

  // Setup base plane
  {
    const planeSize = 4000;

    const loader = new THREE.TextureLoader();
    const texture = loader.load('assets/checker.png');
    texture.wrapS = THREE.RepeatWrapping;
    texture.wrapT = THREE.RepeatWrapping;
    texture.minFilter = THREE.NearestFilter;
    texture.magFilter = THREE.NearestFilter;
    const repeats = planeSize / 200;
    texture.repeat.set(repeats, repeats);

    const planeGeo = new THREE.PlaneBufferGeometry(planeSize, planeSize);
    const planeMat = new THREE.MeshPhongMaterial({
      map: texture,
      side: THREE.DoubleSide,
    });
    const mesh = new THREE.Mesh(planeGeo, planeMat);
    mesh.rotation.x = Math.PI * -.5;
    //scene.add(mesh);
  }

  // Camera helper function
  function frameArea(sizeToFitOnScreen, boxSize, boxCenter, camera) {
    const halfSizeToFitOnScreen = sizeToFitOnScreen * 0.5;
    const halfFovY = THREE.Math.degToRad(camera.fov * .5);
    const distance = halfSizeToFitOnScreen / Math.tan(halfFovY);
    // compute a unit vector that points in the direction the camera is now
    // in the xz plane from the center of the box
    const direction = (new THREE.Vector3())
      .subVectors(camera.position, boxCenter)
      .multiply(new THREE.Vector3(1, 0, 1))
      .normalize();

    // move the camera to a position distance units way from the center
    // in whatever direction the camera was from the center already
    camera.position.copy(direction.multiplyScalar(distance).add(boxCenter));

    // pick some near and far values for the frustum that
    // will contain the box.
    camera.near = boxSize / 100;
    camera.far = boxSize * 100;

    camera.updateProjectionMatrix();

    // point the camera to look at the center of the box
    camera.lookAt(boxCenter.x, boxCenter.y, boxCenter.z);
  }

  // https://stackoverflow.com/questions/29325906/can-you-use-raw-webgl-textures-with-three-js
  const forceTextureInitialization = function() {
    const material = new THREE.MeshBasicMaterial();
    const geometry = new THREE.PlaneBufferGeometry();
    const scene = new THREE.Scene();
    scene.add(new THREE.Mesh(geometry, material));
    const camera = new THREE.Camera();

    return function forceTextureInitialization(texture) {
      material.map = texture;
      modelRenderer.render(scene, camera);
    };
  }();

  {
    const objLoader = new OBJLoader();

    objLoader.load( 'assets/steve.obj', (root) => {
      scene.add(root);

      root.traverse( async (child) => {
        if ( child.isMesh ) {
          // Hack to force in webgl texture in three
          // https://stackoverflow.com/questions/29325906/can-you-use-raw-webgl-textures-with-three-js
          const texture = new THREE.Texture();
          forceTextureInitialization(texture);
          const texProps = modelRenderer.properties.get(texture);
          texProps.__webglTexture = glModelTexture;

          const material = new THREE.ShaderMaterial({
            uniforms: {
              Sampler0: { type: "t", value: texture }
            },
            vertexShader: await fetch("shader/vertex.glsl", {credentials: 'same-origin'}).then((response) => response.text()),
            fragmentShader: await fetch("shader/fragment.glsl", {credentials: 'same-origin'}).then((response) => response.text()),
            glslVersion: THREE.GLSL3,
            side: THREE.DoubleSide,
          });

          child.material = material;
        }
      });

      scene.add(root);

      // CAMERA CONTROLS
      const box = new THREE.Box3().setFromObject(root);
      const boxSize = box.getSize(new THREE.Vector3()).length();
      const boxCenter = box.getCenter(new THREE.Vector3());
      frameArea(boxSize * 1.2, boxSize, boxCenter, camera);
      controls.maxDistance = boxSize * 10;
      controls.target.copy(boxCenter);
      controls.update();
    });
  }

  function resizeRendererToDisplaySize(renderer) {
    const canvas = renderer.domElement;
    const width = canvas.clientWidth;
    const height = canvas.clientHeight;
    const needResize = canvas.width !== width || canvas.height !== height;
    if (needResize) {
      renderer.setSize(width, height, false);
    }
    return needResize;
  }

  function render() {
    if (resizeRendererToDisplaySize(modelRenderer)) {
      const canvas = modelRenderer.domElement;
      camera.aspect = canvas.clientWidth / canvas.clientHeight;
      camera.updateProjectionMatrix();
    }
    //skinTexture.needsUpdate = true;

    modelRenderer.render(scene, camera);
    glPreview.drawArrays(gl.POINTS, 0, 1);

    requestAnimationFrame(render);
  }

  requestAnimationFrame(render);
}

main();
