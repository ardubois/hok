require Hok
require Integer
#Nx.default_backend(EXLA.Backend)
#import Nx
Hok.defmodule_rts DP do
include CAS
  deft map_2kernel (arr a) ~> (arr b) ~> (arr c) ~> integer ~> [a ~> b ~> c]
  defk map_2kernel(a1,a2,a3,size,f) do
    id = blockIdx.x * blockDim.x + threadIdx.x
    if(id < size) do
      a3[id] = f(a1[id],a2[id])
    end
  end
  def map2(t1,t2,func) do

    {l,c} = Hok.get_shape_gnx(t1)
    type = Hok.get_type_gnx(t2)
     size = l*c
     result_gpu = Hok.new_gnx(l,c, type)

      threadsPerBlock = 256;
      numberOfBlocks = div(size + threadsPerBlock - 1, threadsPerBlock)

      Hok.spawn_rts(&DP.map_2kernel/5,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[t1,t2,result_gpu,size,func])


      result_gpu
  end
  def reduce(ref, initial, f) do

     {l,c} = Hok.get_shape_gnx(ref)
     type = Hok.get_type_gnx(ref)
     size = l*c
      result_gpu  = Hok.new_gnx(Nx.tensor([[initial]] , type: type))

      threadsPerBlock = 256
      blocksPerGrid = div(size + threadsPerBlock - 1, threadsPerBlock)
      numberOfBlocks = blocksPerGrid
      Hok.spawn_rts(&DP.reduce_kernel/5,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[ref,result_gpu, initial,f, size])
      result_gpu
  end
  deft reduce_kernel (arr a) ~> (arr a) ~> a ~> [a ~> a ~> a ] ~> integer
  defk reduce_kernel(a, ref4, initial,f,n) do

    __shared__ cache[256]

    tid = threadIdx.x + blockIdx.x * blockDim.x;
    cacheIndex = threadIdx.x

    temp = initial

    while (tid < n) do
      temp = f(a[tid], temp)
      tid = blockDim.x * gridDim.x + tid
    end

    cache[cacheIndex] = temp
      __syncthreads()

    i = blockDim.x/2

    while (i != 0 ) do  ###&& tid < n) do
      #tid = blockDim.x * gridDim.x + tid
      if (cacheIndex < i) do
        cache[cacheIndex] = f(cache[cacheIndex + i] , cache[cacheIndex])
      end

    __syncthreads()
    i = i/2
    end

  if (cacheIndex == 0) do
    current_value = ref4[0]
    while(!(current_value == atomic_cas(ref4,current_value,f(cache[0],current_value)))) do
      current_value = ref4[0]
    end
  end

  end
  def replicate(n, x), do: (for _ <- 1..n, do: x)
  def rep_change(n,x), do: rep_pos(n,x)
  def rep_pos(0,_x), do: []
  def rep_pos(n,x), do:  [x | rep_neg(n-1,x)]
  def rep_neg(0,_x), do: []
  def rep_neg(n,x), do:  [-x | rep_pos(n-1,x)]
  def new_dataset_nx_a(n), do: gen_nx_f(n,a_gen_new_dataset_nx_f(div(n,2),<<>>,<<>>))
  defp a_gen_new_dataset_nx_f(0,a1,a2), do: <<a1::binary,a2::binary>>
  defp a_gen_new_dataset_nx_f(size, a1,a2) do

    {ax,ay} = if (rem(size,2) == 0) do
                v = :rand.uniform(100)/1
                {v,-v}
              else
                v = :rand.uniform(100)/1
                {-v,v}
              end

    a_gen_new_dataset_nx_f(
        size - 1,
        <<a1::binary, ax::float-little-32>>,
        <<a2::binary, ay::float-little-32>>
    )
  end
  def new_dataset_nx_b(n), do: gen_nx_f(n,b_gen_new_dataset_nx_f(div(n,2),<<>>,<<>>))
  defp b_gen_new_dataset_nx_f(0,b1,b2), do: <<b1::binary,b2::binary>>
  defp b_gen_new_dataset_nx_f(size, b1,b2) do

    b = :rand.uniform(5)/1

    b_gen_new_dataset_nx_f(
        size - 1,
        <<b1::binary, b::float-little-32>>,
        <<b2::binary, b::float-little-32>>
    )
  end
  defp gen_nx_f(size,ref), do:  %Nx.Tensor{data: %Nx.BinaryBackend{ state: ref}, type: {:f,32}, shape: {1,size}, names: [nil,nil]}
end
#Hok.include [DP]

[arg] = System.argv()

n = String.to_integer(arg)

Hok.include_rts [DP]
Hok.set_default_type(%{default:  :float, a: :float, b: :float, c: :float })

#{vet1,_} = Nx.Random.uniform(Nx.Random.key(1), shape: {1, n}, type: :f32)
#{vet2,_} = Nx.Random.uniform(Nx.Random.key(1), shape: {1, n}, type: :f32)

#vet1 = Hok.new_nx_from_function(1,n,{:f,32},fn -> 1 end )
#vet2 = Hok.new_nx_from_function(1,n,{:f,32},fn -> 0.1 end )

#vet1 = Hok.new_nx_from_function_arg(1,n,{:f,32},fn x -> if Integer.is_even(x) do 10 else -10 end end )
#vet2 = Hok.new_nx_from_function(1,n,{:f,32},fn  -> 1 end)

#vet1 = DP.new_dataset_nx(n)
#vet2 = Hok.new_nx_from_function(1,n,{:f,32},fn  -> 1 end)

vet1 = DP.new_dataset_nx_a(n)
vet2 = DP.new_dataset_nx_b(n)

#vet2 = Nx.tensor(DP.rep_change(n,1), type: {:f,32})
#vet1 = Nx.iota({1,n}, type: :f32)
#vet2 = Nx.iota({1,n}, type: :f32)

#vet1 = Hok.new_nx_from_function(1,n,{:f,32},fn -> :rand.uniform(1000) end )
#vet2 = Hok.new_nx_from_function(1,n,{:f,32},fn -> :rand.uniform(1000) end)

#vet1 = Hok.new_nx_from_function(1,n,{:f,32},fn -> 1.0 end )
#vet2 = Nx.tensor([Enum.to_list(1..n)], type: {:f,32})

prev = System.monotonic_time()

#IO.inspect vet2

ref1 = Hok.new_gnx(vet1)

ref2 = Hok.new_gnx(vet2)


_result = ref1
    |> DP.map2(ref2, Hok.hok_rts fn (a,b) -> a * b end)
    |> DP.reduce(0.0,Hok.hok_rts fn (a,b) -> a + b end)
    |> Hok.get_gnx

#IO.inspect result

next = System.monotonic_time()


IO.puts "Hok\t#{n}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"
