require Hok
Hok.defmodule Julia do
  deft julia integer ~> integer ~> integer ~> integer
  defh julia(x,y,dim) do
    var scale float = 0.1
    var jx float = scale * (dim - x)/dim
    var jy float = scale * (dim - y)/dim

    var cr float = -0.8
    var ci float = 0.156
    var ar float = jx
    var ai float = jy
    for i in range(0,200) do
        var nar float = (ar*ar - ai*ai) + cr
        var nai float = (ai*ar + ar*ai) + ci
        if ((nar * nar)+(nai * nai ) > 1000.0) do
          return 0
        end
        ar = nar
        ai = nai
    end
    return 1
  end
  deft julia_kernel gmatrex ~> integer ~> integer ~> integer ~> integer
  defh julia_kernel(ptr,x,y,dim) do
    var offset int = x + y * dim # gridDim.x
    var juliaValue float = julia(x,y,dim)

    ptr[offset*4 + 0] = 255 * juliaValue;
    ptr[offset*4 + 1] = 0;
    ptr[offset*4 + 2] = 0;
    ptr[offset*4 + 3] = 255;
    return 1
  end


  deft mapgen2D_xy_1para_noret_ker gmatrex ~> integer ~> integer ~>[gmatrex ~> integer ~> integer~> integer ~> integer] ~> unit
  defk mapgen2D_xy_1para_noret_ker(resp,arg1,size,f)do
    var x int= blockIdx.x * blockDim.x + threadIdx.x
    var y int  = blockIdx.y * blockDim.y + threadIdx.y

    if(x < size && y < size) do
      var v int=f(resp,x,y,arg1)
    end
  end
  def mapgen2D_xy_1para_noret(arg1, size,f) do

    result_gpu = Hok.new_gmatrex(1,size*size)

    Hok.spawn(&Julia.mapgen2D_xy_1para_noret_ker/5,{size,size,1},{1,1,1},[result_gpu,arg1,size,f])
    r_gpu = Hok.get_gmatrex(result_gpu)
    r_gpu
  end
end

include [Julia]

[arg] = System.argv()
m = String.to_integer(arg)

dim = m


prev = System.monotonic_time()

ref = mapgen2D_xy_1para_noret(dim,dim, &Julia.julia_kernel/4)

_image = GPotion.get_gmatrex(ref)
next = System.monotonic_time()

IO.puts "GPotion\t#{dim}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"
