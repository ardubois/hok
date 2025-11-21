require Hok

Hok.defmodule Teste do

defk teste_kernel(a) do
   index = blockIdx.x * blockDim.x + threadIdx.x;
   a[index] = a[index] + 1
 end
end

Hok.include [Teste]



t = Nx.tensor([[1, 2, 3, 4]],type: {:s, 32})

#t = Matrex.new([[1,2,3,4]])
size = 4
gm = Hok.new_gnx(t)

IO.inspect gm

threadsPerBlock = 128;
numberOfBlocks = div(size + threadsPerBlock - 1, threadsPerBlock)
Hok.spawn(&Teste.teste_kernel/1,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[gm])

mt = Hok.get_gnx(gm)

IO.inspect mt
