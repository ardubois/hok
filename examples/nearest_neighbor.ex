require Integer
require Hok
defmodule DataSet do
  def open_data_set(file) do
    {:ok, contents} = File.read(file)
    contents
    |> String.split("\n", trim: true)
    |> Enum.map(fn f ->  load_file(f) end)
    |> Enum.concat()
    |> Enum.concat()
 #   |> Enum.unzip()
  end
  def load_file(file) do
    #IO.puts file
    {:ok, contents} = File.read(file)
    contents
    |> String.split("\n", trim: true)
    |> Enum.map(fn line -> words = String.split(line, " ", trim: true)
                           [ elem(Float.parse(Enum.at(words, 6)),0), elem(Float.parse(Enum.at(words,7)), 0) ] end  )
  end
  def gen_data_set(n), do: gen_data_set_(n,[])
  def gen_data_set_(0,data), do: data
  def gen_data_set_(n,data) do
    lat = (7 + Enum.random(0..63)) + :rand.uniform();
      lon = (Enum.random(0..358)) + :rand.uniform();
      gen_data_set_(n-1, [lat,lon|data])

  end
  def gen_lat_long(_l,c) do
    if(Integer.is_even(c)) do
      (Enum.random(0..358)) + :rand.uniform()
    else
      (7 + Enum.random(0..63)) + :rand.uniform()
    end
  end
end


Hok.defmodule NN do
  def euclid_seq(l,lat,lng), do: euclid_seq_(l,lat,lng,[])
  def euclid_seq_([m_lat,m_lng|array],lat,lng,data) do
    # m_lat = Enum.at(array,0)
     #m_lng = Enum.at(array,1)

     value = :math.sqrt((lat-m_lat)*(lat-m_lat)+(lng-m_lng)*(lng-m_lng))
     #value = :math.sqrt((lat-m_lat)*(lat-m_lat)+(lng-m_lng)*(lng-m_lng))
     euclid_seq_(array,lat,lng,[value|data])
  end
  def euclid_seq_([],_lat,_lng, data) do
    data
  end
  deft map_step_2para_1resp_kernel gmatrex ~> gmatrex ~> integer ~> float ~> float ~> integer ~> [gmatrex ~> float ~> float ~> float] ~> unit
  defk map_step_2para_1resp_kernel(d_array, d_result, step,  par1, par2,size,f) do

    var globalId int = blockDim.x * ( gridDim.x * blockIdx.y + blockIdx.x ) + threadIdx.x

    var id int = step * globalId


    if (globalId < size) do
      d_result[globalId] = f(d_array+id, par1,par2)
    end
  end
  def map_step_2para_1resp(d_array,step, par1, par2, size, f) do
      distances_device = Hok.new_gmatrex(1,size)
      Hok.spawn(&NN.map_step_2para_1resp_kernel/7,{size,1,1},{1,1,1},[d_array,distances_device,step,par1,par2,size,f])
      Hok.get_gmatrex(distances_device)
  end
  deft euclid gmatrex ~> float ~> float ~> float
  defh euclid(d_locations, lat, lng) do
    return sqrt((lat-d_locations[0])*(lat-d_locations[0])+(lng-d_locations[1])*(lng-d_locations[1]))
      #return sqrt((lat-d_locations[0])*(lat-d_locations[0])+(lng-d_locations[1])*(lng-d_locations[1]))
    end



end

Hok.include [NN]

[arg] = System.argv()

size = String.to_integer(arg)


list_data_set = DataSet.gen_data_set(2*size)

data_set_host = Matrex.new([list_data_set])

data_set_device = Hok.new_gmatrex(data_set_host)


prev = System.monotonic_time()

distances_device=NN.map_step_2para_1resp(data_set_device,2,0.0,0.0,size, &NN.euclid/3)

Hok.spawn(&NN.map_step_2para_1resp_kernel/7,{size,1,1},{1,1,1},[data_set_device,distances_device,2,0.0,0.0,size,&NN.euclid/3])

dist_result = Hok.get_gmatrex(distances_device)

next = System.monotonic_time()
IO.puts "GPotion\t#{size}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"

result_elixir = Enum.reverse(NN.euclid_seq(list_data_set,0.0,0.0))

v1 = data_set_host[1]
v2 = data_set_host[2]

IO.puts "v1 = #{v1}"
IO.puts "v2 = #{v2}"

IO.inspect(dist_result)

IO.inspect NN.euclid_seq([v1,v2],0.0,0.0)



IO.inspect result_elixir
