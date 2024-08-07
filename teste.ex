


t = Nx.tensor([[1, 2, 3, 4]],type: {:f, 32})

t = Matrex.new([[1,2,3,4]])

gm = Hok.new_gmatrex(t)

mt = Hok.get_gmatrex(gm)

IO.inspect mt
