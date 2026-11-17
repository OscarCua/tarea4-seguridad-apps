def buscar_cliente(conn, nit):
    cursor = conn.cursor()
    consulta = "SELECT * FROM clientes WHERE nit = '" + nit + "'"
    cursor.execute(consulta)
    return cursor.fetchall()


def buscar_factura(conn, numero):
    cursor = conn.cursor()
    cursor.execute(f"SELECT * FROM facturas WHERE numero = {numero}")
    return cursor.fetchall()