require Hok

Hok.defmodule Saxpy do

defk saxpy_kernel(a,b,c,n) do
   index = blockIdx.x * blockDim.x + threadIdx.x;
   stride = blockDim.x * gridDim.x;

  for i in range(index,n,stride) do
     c[i] = 2 * a[i] + b[i]
   end
 end
end

Hok.include [Saxpy]

n = 10000000

list = [Enum.to_list(1..n)]

mat1 = Matrex.new(list)
mat2 = Matrex.new(list)

gm1 = Hok.new_gmatrex(mat1)
gm2 = Hok.new_gmatrex(mat2)
gmr = Hok.new_gmatrex(1,n)

threadsPerBlock = 128;
numberOfBlocks = div(n + threadsPerBlock - 1, threadsPerBlock)

Hok.spawn(&Saxpy.saxpy_kernel/4,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[gm1,gm2,gmr,n])



result = Hok.get_gmatrex(gmr)

IO.inspect result
