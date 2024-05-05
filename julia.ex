require Hok
Hok.defmodule Julia do
  deft julia integer ~> integer ~> integer ~> integer
  defh julia(x,y,dim) do
    scale = 0.1
    jx = scale * (dim - x)/dim
    jy = scale * (dim - y)/dim

    cr = -0.8
    ci = 0.156
    ar = jx
    ai = jy
    for i in range(0,200) do
        nar = (ar*ar - ai*ai) + cr
        nai = (ai*ar + ar*ai) + ci
        if ((nar * nar)+(nai * nai ) > 1000) do
          return 0
        end
        ar = nar
        ai = nai
    end
    return 1
  end
  deft julia_kernel gmatrex ~> integer ~> integer ~> integer ~> integer
  defh julia_kernel(ptr,x,y,dim) do
    offset = x + y * dim # gridDim.x
    juliaValue = julia(x,y,dim)

    ptr[offset*4 + 0] = 255 * juliaValue;
    ptr[offset*4 + 1] = 0;
    ptr[offset*4 + 2] = 0;
    ptr[offset*4 + 3] = 255;
    return 1
  end
  end

  defh mapgen2D_xy_1para_noret_ker gmatrex ~> integer ~> integer ~>integer ~> [gmatrex ~> integer ~> integer~> integer~> void] ~> void
  defk mapgen2D_xy_1para_noret_ker(resp,arg1,size,f)do
    x = blockIdx.x * blockDim.x + threadIdx.x
    y  = blockIdx.y * blockDim.y + threadIdx.y

    if(x < size && y < size) do
      f(resp,x,y,arg1)
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
