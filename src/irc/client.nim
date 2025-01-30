import net

type Client = object 
  connections: seq[Socket]

  

func newClient*(): Client = Client()
