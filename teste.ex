require Hok
m = 1000
#n = m
k=m
mat = Matrex.fill(1,m*k,1)

f = fn _ -> Enum.random(1..100) end


mat1 = Matrex.apply(mat,f)
mat2 = Matrex.apply(mat,f)


result = MM.comp2xy2D(mat1,mat2,1000,1000, Hok.hok fn (mat1,mat2,x,y) ->
  mat1[x * 1000 + 10] * mat2[10 * 1000 + y]
 end)
