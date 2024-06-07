require Hok

Hok.defmodule Saxpy do
import Hok
defk saxpy_kernel(a,b,c,n) do
   intex = blockIdx.x * blockDim.x + threadIdx.x;
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

gmatrex1 = Hok.new_gmatrex(vet1)
gmatrex2 = Hok.new_gmatrex(vet2)
gmatrex3 = Hok.new_gmatrex(1,n)

threadsPerBlock = 128;
numberOfBlocks = div(n + threadsPerBlock - 1, threadsPerBlock)

Hok.spawn(Saxpy.saxpy_kernel/4,{numberOfBlocks,1,1},{threadsPerBlock,1,1},[ref3,ref1,ref2,n])


next = System.monotonic_time()
IO.puts "time gpu #{System.convert_time_unit(next-prev,:native,:millisecond)}"

result = Hok.get_gmatrex(ref3)
IO.inspect result
