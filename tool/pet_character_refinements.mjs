// Local art direction on top of the MIT-licensed reference definitions.
// Keep edits reproducible and independent from the upstream checkout.
const cream = '#eee3cf';
function volume(id, color, x, y, z, sx, sy, sz, shape = 'sphere', extra = {}) {
  return {id, label: id.replaceAll('-', ' '), shape, x, y, z,
    scaleX: sx, scaleY: sy, scaleZ: sz, face: false,
    baseColor: color, foregroundColor: '#483e36', highlightColor: color,
    shadowColor: '#b9aa91', ...extra};
}
export function refinePet(name, authoredParts, authoredScene, authoredFace, authoredMarks) {
  let parts = structuredClone(authoredParts);
  const scene = structuredClone(authoredScene);
  let face = structuredClone(authoredFace);
  let marks = structuredClone(authoredMarks);
  scene.matte = true;
  scene.lightDistance = 20;
  scene.avatarOutlineStyle = {...scene.avatarOutlineStyle, width: 3, opacity: 52};
  scene.avatarShadowStyle = {...scene.avatarShadowStyle, opacity: 12, softness: 14};
  face.eyeHighlight = {...face.eyeHighlight, enabled: false};
  if (name === 'alpaca') {
    const fleece = '#eadbc2';
    parts = [
      volume('ear-left', fleece, -59, -102, -12, .13, .35, .15, 'ellipse',
        {rotationZ: -10}),
      volume('ear-right', fleece, 59, -103, -12, .13, .35, .15, 'ellipse',
        {rotationZ: 10}),
      volume('inner-ear-left', '#c5a68c', -60, -107, 3, .065, .25, .065, 'ellipse',
        {rotationZ: -10}),
      volume('inner-ear-right', '#c5a68c', 60, -108, 3, .065, .25, .065, 'ellipse',
        {rotationZ: 10}),
      volume('primary', fleece, 0, 8, 0, .60, .66, .69, 'ellipse',
        {face: true, bottomTaper: 12, highlightColor: '#f5e8d1', shadowColor: '#baa587'}),
      volume('forelock-left', fleece, -43, -53, 24, .28, .25, .28),
      volume('forelock-center', fleece, -4, -69, 29, .30, .27, .30),
      volume('forelock-right', fleece, 40, -55, 24, .28, .25, .28),
      volume('muzzle', '#dec9aa', 0, 45, 65, .35, .30, .38, 'ellipse',
        {highlightColor: '#ead7bb', shadowColor: '#bba282'}),
      volume('nose', '#58453a', 0, 43, 111, .055, .035, .035, 'ellipse',
        {shadowColor: '#48392f'}),
    ];
    marks = [];
    face = {...face, width: 25, height: 45, gap: 55, eyeOffsetY: -25,
      leftEyeRotation: -3, rightEyeRotation: 3,
      noseEnabled: false, mouthEnabled: false};
    // A nearly frontal resting pose keeps both upright ears inside the frame.
    scene.viewState = {...scene.viewState, yaw: -.08, pitch: -.05, roll: -.025};
    scene.framePadding = .16;
    scene.surfaceDecals = [];
  }
  if (name === 'sheep') {
    parts = [
      volume('wool-crown-left', cream, -55, -73, -9, .30, .30, .31),
      volume('wool-crown-center', cream, -8, -88, -7, .34, .29, .34),
      volume('wool-crown-right', cream, 43, -78, -8, .30, .31, .32),
      volume('wool-side-left', cream, -83, -29, -15, .29, .31, .31),
      volume('wool-side-right', cream, 80, -24, -15, .30, .31, .31),
      volume('wool-jaw-left', cream, -66, 24, -17, .28, .29, .31),
      volume('wool-jaw-right', cream, 65, 26, -17, .29, .29, .31),
      volume('wool-chin-left', cream, -31, 60, -17, .29, .24, .30),
      volume('wool-chin-right', cream, 30, 58, -17, .30, .25, .30),
      volume('ear-left', '#b2a18c', -91, -17, 8, .26, .15, .17, 'ellipse', {rotationZ: -20}),
      volume('ear-right', '#b2a18c', 90, -12, 8, .25, .15, .17, 'ellipse', {rotationZ: 24}),
      volume('primary', '#a89781', 0, 24, 23, .56, .64, .62, 'ellipse',
        {face: true, bottomTaper: 9, highlightColor: '#c4b69e', shadowColor: '#7b6e5c'}),
      volume('forelock-left', cream, -23, -56, 49, .22, .21, .20),
      volume('forelock-right', cream, 20, -59, 47, .24, .21, .20),
    ];
    marks = [];
    face = {...face, width: 23, height: 43, gap: 43, eyeOffsetY: 0,
      leftEyeRotation: -3, rightEyeRotation: 4, noseY: 37,
      noseWidth: 15, noseHeight: 10, mouthEnabled: false};
  }
  if (name === 'parrot') {
    const head = {...parts.find(p => p.face), scaleX: .73, scaleY: .76,
      scaleZ: .74, bottomTaper: 13, y: 12};
    parts = [
      volume('beak-lower', '#887158', 0, 46, 87, .16, .09, .15, 'ellipse',
        {shadowColor: '#665543'}),
      volume('beak-upper', '#d5b77f', 0, 30, 76, .43, .29, .48, 'hookedBeak',
        {shadowColor: '#aa8e62'}),
      head,
    ];
    marks = [{id: 'parrot-face-patch', label: 'Soft facial feather mask',
      targetPartId: head.id, side: 'face', shape: 'face-mask',
      x: 0, y: 8, width: 145, height: 115, rotation: 0, opacity: 100, color: '#eee1bf'}];
    face = {...face, width: 23, height: 42, gap: 48, eyeOffsetY: -15,
      leftEyeRotation: -5, rightEyeRotation: 6, mouthEnabled: false};
  }
  return {parts, scene, face, marks};
}
