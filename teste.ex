


t = Nx.tensor([[1, 2, 3, 4]],type: {:f, 32})

gm = Hok.new_gmatrex(t)

mt = Hok.get_gmatrex(gm)

IO.inspect mt
