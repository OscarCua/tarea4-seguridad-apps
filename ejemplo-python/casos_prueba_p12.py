TABLA = "clientes"


# --- Casos INSEGUROS que la regla podria no detectar (falsos negativos) ---

def fn1_operador_porcentaje(conn, nit):
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM clientes WHERE nit = '%s'" % nit)
    return cursor.fetchall()


def fn2_format(conn, nit):
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM clientes WHERE nit = '{}'".format(nit))
    return cursor.fetchall()


def fn3_acumulacion(conn, nit):
    cursor = conn.cursor()
    consulta = "SELECT * FROM clientes WHERE nit = '"
    consulta += nit
    consulta += "'"
    cursor.execute(consulta)
    return cursor.fetchall()


def _armar_consulta(nit):
    return "SELECT * FROM clientes WHERE nit = '" + nit + "'"


def fn4_otra_funcion(conn, nit):
    cursor = conn.cursor()
    cursor.execute(_armar_consulta(nit))
    return cursor.fetchall()


def fn5_cuatro_operandos(conn, nit, serie):
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM facturas WHERE nit = '" + nit + "' AND serie = '" + serie + "'")
    return cursor.fetchall()


# --- Casos SEGUROS que la regla podria marcar (falsos positivos) ---

def fp1_constante(conn):
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM " + TABLA)
    return cursor.fetchall()


def fp2_entero_validado(conn, numero):
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM facturas WHERE numero = " + str(int(numero)))
    return cursor.fetchall()


def fp3_otro_execute(ejecutor, nombre):
    ejecutor.execute("backup-" + nombre)


# --- Control: caso seguro y correcto ---

def control_parametrizada(conn, nit):
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM clientes WHERE nit = %s", (nit,))
    return cursor.fetchall()