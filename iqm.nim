const
  IQM_MAGIC* = "INTERQUAKEMODEL"
  IQM_VERSION* = 2

type
  iqmheader* = object
    magic*:        array[16, char]
    version*:           int32
    filesize*:          int32
    flags*:            uint32
    num_text*:          int32
    ofs_text*:          int32
    num_meshes*:        int32
    ofs_meshes*:        int32
    num_vertexarrays*:  int32
    num_vertexes*:      int32
    ofs_vertexarrays*:  int32
    num_triangles*:     int32
    ofs_triangles*:     int32
    ofs_adjacency*:     int32
    num_joints*:        int32
    ofs_joints*:        int32
    num_poses*:         int32
    ofs_poses*:         int32
    num_anims*:         int32
    ofs_anims*:         int32
    num_frames*:        int32
    num_framechannels*: int32
    ofs_frames*:        int32
    ofs_bounds*:        int32
    num_comment*:       int32
    ofs_comment*:       int32
    num_extensions*:    int32
    ofs_extensions*:    int32

  iqmmesh* = object
    name*:             int32
    material*:         int32
    first_vertex*:     int32
    num_vertexes*:     int32
    first_triangle*:   int32
    num_triangles*:    int32

  VertexArrayKind* {. size: sizeof(cint) .} = enum
    vakPosition     = 0
    vakTexcoord     = 1
    vakNormal       = 2
    vakTangent      = 3
    vakBlendindexes = 4
    vakBlendweights = 5
    vakColor        = 6
    vakCustom       = 0x10

  VertexArrayFormat* {. size: sizeof(cint) .} = enum
    vafByte    = 0
    vafUByte   = 1
    vafShort   = 2
    vafUShort  = 3
    vafInt     = 4
    vafUInt    = 5
    vafHalf    = 6
    vafFloat   = 7
    vafDouble  = 8

  iqmtriangle* = object
    vertex*: array[3, int32]

  iqmadjacency* = object
    triangle*: array[3, int32]

  iqmjoint* = object
    name*: int32
    parent*: int32
    translate*: Vec3f
    rotate*: Quatf
    scale*: Vec3f

  iqmpose* = object
    parent*: int32
    mask*: uint32
    channeloffset*: array[10, float32]
    channelscale*: array[10, float32]

  iqmanim* = object
    name*:        int32
    first_frame*: int32
    num_frames*:  int32
    framerate*:   float32
    flags*:       uint32

  iqmvertexarray* = object
    kind*:    VertexArrayKind
    flags*:   uint32
    format*:  VertexArrayFormat
    size*:    int32
    offset*:  int32

  iqmbounds* = object
    bbmin*:     Vec3f
    bbmax*:     Vec3f
    xyradius*:  float32
    radius*:    float32
    
  iqmMappedMeshData* = object
    position* : ArrayBuffer[Vec3f]
    texcoord* : ArrayBuffer[Vec2f]
    normal*   : ArrayBuffer[Vec3f]
    tangent*  : ArrayBuffer[Vec4f]
    blendindexes* : ArrayBuffer[Vec4[uint8]]
    blendweights* : ArrayBuffer[Vec4[uint8]]

  iqmMappedMesh* = object
    data* : ptr iqmMappedMeshData
    firstVertex* : int
    numVertices* : int

const
  IQM_LOOP* = 1 shl 0

proc memptr[T](header: ptr iqmheader, offset: int32) : ptr T =
  cast[ptr T](cast[int](header) + offset.int)
proc memptr[T](header: ptr iqmheader, offset: int32, num_elements: int32) : DataView[T] =
  dataView[T]( cast[pointer](cast[int](header) + offset.int), num_elements.int )
  
proc mappedMeshData*(header: ptr iqmheader) : iqmMappedMeshData =
  let vertexArrays = memptr[iqmvertexarray](header, header.ofs_vertexarrays, header.num_vertexarrays)
  for va in vertexArrays:
    if va.kind == vakPosition and va.format == vafFloat and va.size == 3:
      result.position = memptr[Vec3f](header, va.offset, header.num_vertexes).arrayBuffer
    if va.kind == vakTexcoord and va.format == vafFloat and va.size == 2:
      result.texcoord = memptr[Vec2f](header, va.offset, header.num_vertexes ).arrayBuffer
    if va.kind == vakNormal and va.format == vafFloat and va.size == 3:
      result.normal = memptr[Vec3f](header, va.offset, header.num_vertexes ).arrayBuffer
    if va.kind == vakTangent and va.format == vafFloat and va.size == 4:
      result.tangent = memptr[Vec4f](header, va.offset, header.num_vertexes ).arrayBuffer
    if va.kind == vakBlendindexes and va.format == vafUByte and va.size == 4:
      result.blendindexes = memptr[Vec4[uint8]](header, va.offset, header.num_vertexes ).arrayBuffer
    if va.kind == vakBlendweights and va.format == vafUByte and va.size == 4:
      result.blendweights = memptr[Vec4[uint8]](header, va.offset, header.num_vertexes ).arrayBuffer

  if result.position.handle == 0:
    echo "did not get positions"
  if result.texcoord.handle == 0:
    echo "did not get texcoords"
  if result.normal.handle == 0:
    echo "did not get normal"
  if result.tangent.handle == 0:
    echo "did not get tangent"
  if result.blendindexes.handle == 0:
    echo "did not get blendindexes"
  if result.blendweights.handle == 0:
    echo "did not get blendweights"
      
proc grouped*[T](t : var seq[T]; groupSize : int) : seq[DataView[T]] =
  result.newSeq(t.len div groupSize + (if t.len mod groupSize == 0: 0 else: 1))
  for i in 0 .. < result.len:
    result[i] = dataView[T]( t[i * groupSize].addr.pointer, min(groupSize, t.len - i * groupSize) )

proc jointPose*(joint: iqmJoint) : JointPose =
  result.translate = joint.translate
  result.rotate    = joint.rotate
  result.scale     = joint.scale

proc jointPose*(data: array[10, float32]): JointPose =
  result.translate = vec3f(data[0], data[1], data[2])
  result.rotate    = quatf(data[3], data[4], data[5], data[6])
  result.scale     = vec3f(data[7], data[8], data[9])
  
proc matrix*(joint : iqmJoint) : Mat4f =
  joint.jointPose.matrix
