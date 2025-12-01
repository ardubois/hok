require Hok
defmodule BMP do
  @on_load :load_nifs
  def load_nifs do
      :erlang.load_nif("./priv/bmp_nifs", 0)
  end
  def gen_bmp_int_nif(_string,_dim,_mat) do
      raise "gen_bmp_nif not implemented"
  end
  def gen_bmp_float_nif(_string,_dim,_mat) do
    raise "gen_bmp_nif not implemented"
end
  def gen_bmp_int(string,dim,%Nx.Tensor{data: data, type: _type, shape: _shape, names: _name}) do
    %Nx.BinaryBackend{ state: array} = data
    gen_bmp_int_nif(string,dim,array)
  end
  def gen_bmp_float(string,dim,%Nx.Tensor{data: data, type: _type, shape: _shape, names: _name}) do
    %Nx.BinaryBackend{ state: array} = data
    gen_bmp_float_nif(string,dim,array)
  end
end

Hok.defmodule_rts Julia do
  deft julia integer ~> integer ~> integer ~> integer
  defd julia(x,y,dim) do
    scale  = 0.1
    jx = scale * (dim - x)/dim
    jy = scale * (dim - y)/dim

    cr  = -0.8
    ci  = 0.156
    ar  = jx
    ai  = jy
    for i in range(0,200) do
        nar = (ar*ar - ai*ai) + cr
        nai = (ai*ar + ar*ai) + ci
        if ((nar * nar)+(nai * nai ) > 1000.0) do
          return 0
        end
        ar = nar
        ai = nai
    end
    return 1
  end
  deft julia_function (arr integer) ~> integer ~> integer ~> integer ~> unit  
  defd julia_function(ptr,x,y,dim) do
    offset = x + y * dim # gridDim.x
    juliaValue = julia(x,y,dim)

    ptr[offset*4 + 0] = 255 * juliaValue;
    ptr[offset*4 + 1] = 0;
    ptr[offset*4 + 2] = 0;
    ptr[offset*4 + 3] = 255;
  end

  deft mapgen2D_xy_1para_noret_ker (arr a) ~> a ~> a ~> [(arr a) ~> a ~> a ~> a ~> unit] ~> unit
  defk mapgen2D_xy_1para_noret_ker(resp,arg1,size,f)do
    x = blockIdx.x * blockDim.x + threadIdx.x
    y = blockIdx.y * blockDim.y + threadIdx.y

    if(x < size && y < size) do
      f(resp,x,y,arg1)
    end
  end
  def mapgen2D_step_xy_1para_noret(result_gpu, arg1, size,f) do

    Hok.spawn_rts(&Julia.mapgen2D_xy_1para_noret_ker/4,{size,size,1},{1,1,1},[result_gpu,arg1,size,f])
    result_gpu
  end
end


Hok.include_rts [Julia]
Hok.set_default_type(:int)


[arg] = System.argv()
m = String.to_integer(arg)

dim = m

#values_per_pixel = 4

result_gpu = Hok.new_gnx(dim*dim,4,{:s,32})

prev = System.monotonic_time()

_image = result_gpu
  |> Julia.mapgen2D_step_xy_1para_noret(dim,dim, &Julia.julia_function/4)
  |> Hok.get_gnx

next = System.monotonic_time()

IO.puts "PolyHok\t#{dim}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"

#BMP.gen_bmp_int('juliaske.bmp',dim,image)
