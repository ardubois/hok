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
  def gen_data_set(0), do: []
  def gen_data_set(n) do
    lat = (7 + Enum.random(0..63)) + :rand.uniform();
      lon = (Enum.random(0..358)) + :rand.uniform();
      [lat,lon|gen_data_set(n-1)]
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
  def euclid_seq([],_lat,_lng) do
    []
  end
  def euclid_seq(array,lat,lng) do
     m_lat = Enum.at(array,0)
     m_lng = Enum.at(array,1)
     value = :math.sqrt((lat-m_lat)*(lat-m_lat)+(lng-m_lng)*(lng-m_lng))
     [value|euclid_seq(Enum.drop(array,2),lat,lng)]
  end
  defk map_step_2para_1resp_kernel(d_array, d_result, step,  par1, par2,size,f) do
    globalId = blockDim.x * ( gridDim.x * blockIdx.y + blockIdx.x ) + threadIdx.x
    id = step * globalId
    if (globalId < size) do
      d_result[globalId] = f(d_array+id, par1,par2)
    end
  end

  defh euclid(d_locations, lat, lng) do
      sqrt((lat-d_locations[0])*(lat-d_locations[0])+(lng-d_locations[1])*(lng-d_locations[1]))
    end



end
 #d1 = DataSet.open_data_set("files")
#IO.inspect(d1)

#d1 = DataSet.gen_data_set(100000000)
#d1 = DataSet.gen_data_set(1000000)

[arg] = System.argv()

usr_size = String.to_integer(arg)
#d1 = DataSet.gen_data_set(usr_size)


size = usr_size

m1 = Matrex.new(1,2*usr_size,&DataSet.gen_lat_long/2)


prev = System.monotonic_time()

locations = GPotion.new_gmatrex(m1)
distances = GPotion.new_gmatrex(1,size)

GPotion.spawn(ker,{size,1,1},{1,1,1},[locations,distances,size,0,0])

_dist_result = GPotion.get_gmatrex(distances)

next = System.monotonic_time()
IO.puts "GPotion\t#{usr_size}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"


#IO.inspect(m1)
