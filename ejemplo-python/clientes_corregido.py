def buscar_cliente(conn, nit):
    cursor = conn.cursor()
    consulta = "SELECT * FROM clientes WHERE nit = %s"
    cursor.execute(consulta, (nit,))
    return cursor.fetchall()


def buscar_factura(conn, numero):
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM facturas WHERE numero = %s", (numero,))
    return cursor.fetchall()