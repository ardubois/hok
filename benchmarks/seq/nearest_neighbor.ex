require Integer

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
      gen_data_set_(n-1, [{lat,lon}|data])

  end
  def gen_lat_long(_l,c) do
    if(Integer.is_even(c)) do
      (Enum.random(0..358)) + :rand.uniform()
    else
      (7 + Enum.random(0..63)) + :rand.uniform()
    end
  end
end


defmodule NN do
  def euclid({lat1,lng1}, lat, lng) do
    :math.sqrt((lat-lat1)*(lat-lat1)+(lng-lng1)*(lng-lng1))
      #return sqrt((lat-d_locations[0])*(lat-d_locations[0])+(lng-d_locations[1])*(lng-d_locations[1]))
  end

  def menor(x,y) do
    if y == 0.0 do
      x
    else
     if (x<y) do
      x
     else
      y
     end
    end
  end
end

[arg] = System.argv()

size = String.to_integer(arg)


list_data_set = DataSet.gen_data_set(size)


prev = System.monotonic_time()

_nn = list_data_set
      |> Enum.map(fn a -> NN.euclid(a,0,0) end)
      |> Enum.reduce(0,&NN.menor/2)


next = System.monotonic_time()
IO.puts "Elixir\t#{size}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"

#result_elixir = Enum.reverse(NN.euclid_seq(list_data_set,0.0,0.0))



#IO.puts("NN = #{nn[1]}")


#IO.inspect (Enum.reduce(result_elixir,0, fn (x,y)-> if y == 0 do x else if x<y do x else y end end end))
