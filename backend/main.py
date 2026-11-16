import os
import re
from datetime import datetime, date, timedelta
from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error
from werkzeug.security import generate_password_hash, check_password_hash
from ldap3 import Server, Connection, SUBTREE

app = Flask(__name__)
CORS(app)

AD_SERVER_IP = os.environ.get('AD_SERVER_IP', '172.31.5.79')
AD_DOMAIN = os.environ.get('AD_DOMAIN', 'instapac.local')
AD_BASE_DN = os.environ.get('AD_BASE_DN', 'DC=instapac,DC=local')

def get_db_connection():
    return mysql.connector.connect(
        host=os.environ.get('DB_HOST', 'database'),
        user=os.environ.get('DB_USER', 'root'),
        password=os.environ.get('DB_PASSWORD', 'instapac_root'),
        database=os.environ.get('DB_NAME', 'instapac_db')
    )

def obtener_parametros_sistema(cursor):
    cursor.execute("SELECT clave, valor FROM Parametros_Sistema")
    filas = cursor.fetchall()
    params = {'PORCENTAJE_COBERTURA': 80.0, 'PORCENTAJE_PRIMA': 4.0, 'DIAS_MAX_BOLETA': 30, 'PLAZO_MAX_REEMBOLSO': 14}
    for f in filas:
        c = f['clave'] if isinstance(f, dict) else f[0]
        v = f['valor'] if isinstance(f, dict) else f[1]
        try:
            params[c] = float(v)
        except ValueError:
            params[c] = v
    return params

def es_correo_institucional_valido(correo):
    patron = r'^[a-zA-Z0-9._%+-]+@([a-zA-Z0-9-]+\.)*(edu\.pe|edu|instapac\.local)$'
    return re.match(patron, correo.strip(), re.IGNORECASE) is not None

def autenticar_y_autorizar_ad(correo_o_usuario, password):
    """Autentica en AD y verifica obligatoriamente la membresía en el grupo APP_ADMIN de la OU InstaPac."""
    if not correo_o_usuario or not password or AD_SERVER_IP == '172.31.0.0':
        return None
    username = correo_o_usuario.split('@')[0].strip()
    user_upn = f"{username}@{AD_DOMAIN}"
    try:
        server = Server(AD_SERVER_IP, port=389, connect_timeout=3)
        conn_ad = Connection(server, user=user_upn, password=password, auto_bind=True, receive_timeout=3)
        
        # 1. Obtener nombre del usuario
        conn_ad.search(search_base=AD_BASE_DN, search_filter=f"(sAMAccountName={username})", search_scope=SUBTREE, attributes=['cn', 'displayName', 'distinguishedName'])
        if not conn_ad.entries:
            conn_ad.unbind()
            return None
            
        entry = conn_ad.entries[0]
        nombre_ad = str(entry.displayName.value) if 'displayName' in entry and entry.displayName.value else username

        # 2. Verificar pertenencia estricta al grupo de seguridad APP_ADMIN en la OU
        es_miembro_admin = False
        try:
            conn_ad.search(
                search_base=AD_BASE_DN,
                search_filter="(&(objectClass=group)(cn=APP_ADMIN))",
                search_scope=SUBTREE,
                attributes=['member']
            )
            if conn_ad.entries:
                group_entry = conn_ad.entries[0]
                if 'member' in group_entry:
                    miembros = [str(m).upper() for m in group_entry.member.values]
                    user_dn = str(entry.distinguishedName.value).upper()
                    if any(user_dn == m or username.upper() in m for m in miembros):
                        es_miembro_admin = True
        except Exception:
            pass

        conn_ad.unbind()

        # Si no pertenece al grupo autorizado APP_ADMIN, se deniega el acceso al panel administrativo
        if not es_miembro_admin:
            return {"error_autorizacion": "Acceso denegado: Tu cuenta de Active Directory no pertenece al grupo autorizado APP_ADMIN."}

        return {
            "username": username,
            "correo": user_upn,
            "nombre": nombre_ad,
            "rol_bd": 'Administrador'
        }
    except Exception as e:
        return None

@app.route('/api/catalogo', methods=['GET'])
def obtener_catalogo():
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        params = obtener_parametros_sistema(cursor)
        cursor.execute("SELECT id_catalogo, tipo_dispositivo, marca, modelo, activo FROM Catalogo_Dispositivos WHERE activo = 1 ORDER BY marca, modelo")
        return jsonify({"catalogo": cursor.fetchall(), "parametros": params}), 200
    except Error as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

@app.route('/api/registro', methods=['POST'])
def registro_usuario():
    datos = request.json or {}
    correo = (datos.get('correo') or '').strip()
    password = datos.get('password') or ''
    nombre = (datos.get('nombre_completo') or '').strip()
    dni = (datos.get('dni') or '').strip()
    telefono = (datos.get('telefono') or '').strip()
    codigo_uni = (datos.get('codigo_universitario') or '').strip()
    cuenta_reembolso = (datos.get('cuenta_reembolso') or f"Yape: {telefono}").strip()

    if not correo or not password or not nombre or not dni or not codigo_uni:
        return jsonify({"error": "Todos los campos son obligatorios."}), 400
    if len(dni) != 8 or not dni.isdigit():
        return jsonify({"error": "El DNI debe contener 8 dígitos numéricos."}), 400
    if not es_correo_institucional_valido(correo):
        return jsonify({"error": "Debes registrarte con un correo institucional universitario (.edu.pe o .edu)."}), 400

    hashed_pw = generate_password_hash(password)
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("INSERT INTO Clientes (nombre_completo, dni, codigo_universitario, telefono, cuenta_reembolso) VALUES (%s, %s, %s, %s, %s)", (nombre, dni, codigo_uni, telefono, cuenta_reembolso))
        id_cli = cursor.lastrowid
        cursor.execute("INSERT INTO Usuarios (id_cliente, correo_universitario, password_hash, rol, estado) VALUES (%s, %s, %s, 'Cliente', 'Activo')", (id_cli, correo, hashed_pw))
        id_usu = cursor.lastrowid
        conn.commit()
        return jsonify({"mensaje": "Cuenta creada exitosamente.", "id_usuario": id_usu}), 201
    except Error as e:
        conn.rollback()
        return jsonify({"error": f"Error al registrar (verifica DNI o correo duplicado): {str(e)}"}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

@app.route('/api/login', methods=['POST'])
def login():
    datos = request.json or {}
    correo = (datos.get('correo') or '').strip()
    password = datos.get('password') or ''

    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        es_intento_ad = ('@' not in correo) or correo.lower().endswith('@instapac.local')

        # 1. Si es estudiante local (MySQL)
        if not es_intento_ad:
            cursor.execute("""
                SELECT u.id_usuario, u.correo_universitario, u.password_hash, u.rol, u.estado, c.nombre_completo 
                FROM Usuarios u LEFT JOIN Clientes c ON u.id_cliente = c.id_cliente
                WHERE u.correo_universitario = %s
            """, (correo,))
            usuario = cursor.fetchone()
            if usuario and check_password_hash(usuario['password_hash'], password):
                if usuario['estado'] == 'Inactivo':
                    return jsonify({"error": "Tu cuenta ha sido desactivada por el administrador."}), 403
                return jsonify({
                    "mensaje": "Login exitoso",
                    "id_usuario": usuario['id_usuario'],
                    "nombre": usuario['nombre_completo'] or "Estudiante Universitario",
                    "rol": 'cliente'
                }), 200

        # 2. Si es administrador institucional (Active Directory)
        resultado_ad = autenticar_y_autorizar_ad(correo, password)
        if resultado_ad:
            if "error_autorizacion" in resultado_ad:
                return jsonify({"error": resultado_ad["error_autorizacion"]}), 403

            cursor.execute("""
                SELECT u.id_usuario, u.rol, u.estado, c.nombre_completo 
                FROM Usuarios u LEFT JOIN Clientes c ON u.id_cliente = c.id_cliente
                WHERE u.correo_universitario = %s OR u.correo_universitario = %s
            """, (correo, resultado_ad['correo']))
            usuario_bd = cursor.fetchone()

            if not usuario_bd:
                dni_gen = str(abs(hash(resultado_ad['username'])) % 90000000 + 10000000)
                cursor.execute("INSERT INTO Clientes (nombre_completo, dni, codigo_universitario, telefono, cuenta_reembolso) VALUES (%s, %s, %s, 'AD-CORP', 'Cuenta AD')", (resultado_ad['nombre'], dni_gen, f"AD-{dni_gen[:5]}"))
                id_cli = cursor.lastrowid
                cursor.execute("INSERT INTO Usuarios (id_cliente, correo_universitario, password_hash, rol, estado) VALUES (%s, %s, %s, %s, 'Activo')", (id_cli, resultado_ad['correo'], generate_password_hash(os.urandom(16).hex()), 'Administrador'))
                id_usu = cursor.lastrowid
                conn.commit()
                nombre_final = resultado_ad['nombre']
            else:
                if usuario_bd['estado'] == 'Inactivo':
                    return jsonify({"error": "Tu cuenta se encuentra suspendida."}), 403
                id_usu = usuario_bd['id_usuario']
                nombre_final = usuario_bd['nombre_completo'] or resultado_ad['nombre']
                cursor.execute("UPDATE Usuarios SET rol = 'Administrador' WHERE id_usuario = %s", (id_usu,))
                conn.commit()

            return jsonify({
                "mensaje": "Login exitoso vía Active Directory (APP_ADMIN)",
                "id_usuario": id_usu,
                "nombre": f"{nombre_final} (AD)",
                "rol": 'admin'
            }), 200

        return jsonify({"error": "Credenciales incorrectas o cuenta no autorizada en Active Directory."}), 401
    except Error as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

@app.route('/api/cliente/<int:id_usuario>/perfil', methods=['GET', 'PUT'])
def perfil_cliente(id_usuario):
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        if request.method == 'GET':
            cursor.execute("SELECT u.id_usuario, u.correo_universitario, u.estado, c.* FROM Usuarios u JOIN Clientes c ON u.id_cliente = c.id_cliente WHERE u.id_usuario = %s", (id_usuario,))
            p = cursor.fetchone()
            return (jsonify(p), 200) if p else (jsonify({"error": "No encontrado"}), 404)
        datos = request.json or {}
        cursor.execute("SELECT id_cliente FROM Usuarios WHERE id_usuario = %s", (id_usuario,))
        u = cursor.fetchone()
        cursor.execute("UPDATE Clientes SET nombre_completo=%s, codigo_universitario=%s, telefono=%s, cuenta_reembolso=%s WHERE id_cliente=%s",
                       (datos.get('nombre_completo'), datos.get('codigo_universitario'), datos.get('telefono'), datos.get('cuenta_reembolso'), u['id_cliente']))
        conn.commit()
        return jsonify({"mensaje": "Perfil actualizado correctamente.", "nombre": datos.get('nombre_completo')}), 200
    except Error as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

@app.route('/api/equipos', methods=['POST'])
def registrar_equipo():
    datos = request.json or {}
    id_usuario = datos.get('id_usuario')
    tipo = datos.get('tipo_equipo', 'Celular')
    marca = (datos.get('marca') or '').strip()
    modelo = (datos.get('modelo') or '').strip()
    nro_serie = (datos.get('nro_serie') or '').strip()
    fecha_compra_str = (datos.get('fecha_compra') or '').strip()
    archivo_boleta = (datos.get('archivo_boleta') or 'Boleta_Verificada.pdf').strip()
    valor_declarado = float(datos.get('valor_declarado') or 0)

    if not nro_serie or len(nro_serie) < 6:
        return jsonify({"error": "Ingresa un IMEI o Número de Serie válido."}), 400
    if valor_declarado < 200 or valor_declarado > 25000:
        return jsonify({"error": "El valor en boleta debe ser real (mín. S/ 200.00)."}), 400

    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        params = obtener_parametros_sistema(cursor)
        dias_max = int(params.get('DIAS_MAX_BOLETA', 30))
        fecha_compra = datetime.strptime(fecha_compra_str, '%Y-%m-%d').date()
        dias_ant = (date.today() - fecha_compra).days
        if dias_ant < 0 or dias_ant > dias_max:
            return jsonify({"error": f"La boleta tiene {dias_ant} días y el límite permitido es de {dias_max} días."}), 400

        cursor.execute("SELECT id_cliente FROM Usuarios WHERE id_usuario = %s", (id_usuario,))
        res = cursor.fetchone()
        cursor.execute("SELECT id_equipo FROM Equipos WHERE nro_serie = %s", (nro_serie,))
        if cursor.fetchone():
            return jsonify({"error": "El IMEI o Serie ingresado ya está registrado."}), 400

        cursor.execute("INSERT INTO Equipos (id_cliente, tipo_dispositivo, marca, modelo, nro_serie, fecha_compra, valor_declarado) VALUES (%s,%s,%s,%s,%s,%s,%s)",
                       (res['id_cliente'], tipo, marca, modelo, nro_serie, fecha_compra_str, valor_declarado))
        id_eq = cursor.lastrowid
        cursor.execute("INSERT INTO Solicitudes (id_equipo, estado, ruta_foto_evidencia, observaciones) VALUES (%s, 'Pendiente', %s, 'En evaluación técnica.')", (id_eq, archivo_boleta))
        id_sol = cursor.lastrowid
        conn.commit()
        return jsonify({"mensaje": f"Solicitud #TCK-{id_sol:03d} registrada correctamente."}), 201
    except Error as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

@app.route('/api/cliente/<int:id_usuario>/datos', methods=['GET'])
def obtener_datos_cliente(id_usuario):
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        params = obtener_parametros_sistema(cursor)
        pct_prima = float(params.get('PORCENTAJE_PRIMA', 4.0)) / 100.0
        pct_cob = float(params.get('PORCENTAJE_COBERTURA', 80.0)) / 100.0
        plazo_reemb = int(params.get('PLAZO_MAX_REEMBOLSO', 14))

        cursor.execute("SELECT u.id_cliente, c.*, u.correo_universitario FROM Usuarios u JOIN Clientes c ON u.id_cliente = c.id_cliente WHERE u.id_usuario = %s", (id_usuario,))
        user = cursor.fetchone()
        if not user:
            return jsonify({"equipos": [], "polizas": [], "pagos": [], "siniestros": [], "parametros": params}), 200
        id_cli = user['id_cliente']

        cursor.execute("""
            SELECT e.id_equipo, e.tipo_dispositivo, e.marca, e.modelo, e.nro_serie,
                   DATE_FORMAT(e.fecha_compra, '%d/%m/%Y') AS fecha_compra, e.valor_declarado,
                   DATE_FORMAT(e.fecha_registro, '%d/%m/%Y %H:%i') AS fecha_registro,
                   s.id_solicitud, s.estado, s.ruta_foto_evidencia, IFNULL(s.observaciones, '') AS observaciones,
                   p.id_poliza, p.numero_poliza, p.estado AS estado_poliza
            FROM Equipos e JOIN Solicitudes s ON e.id_equipo = s.id_equipo
            LEFT JOIN Polizas p ON s.id_solicitud = p.id_solicitud
            WHERE e.id_cliente = %s ORDER BY s.id_solicitud DESC
        """, (id_cli,))
        equipos = cursor.fetchall()
        for eq in equipos:
            eq['codigo_ticket'] = f"#TCK-{eq['id_solicitud']:03d}"
            eq['valor_declarado'] = float(eq['valor_declarado'])
            eq['prima_mensual'] = round(eq['valor_declarado'] * pct_prima, 2)
            eq['cobertura_max'] = round(eq['valor_declarado'] * pct_cob, 2)

        cursor.execute("""
            SELECT p.id_poliza, p.id_solicitud, p.numero_poliza, p.estado,
                   DATE_FORMAT(p.fecha_inicio, '%d/%m/%Y') AS fecha_inicio,
                   DATE_FORMAT(p.fecha_fin, '%d/%m/%Y') AS fecha_fin,
                   e.tipo_dispositivo, e.marca, e.modelo, e.nro_serie, e.valor_declarado,
                   (SELECT COUNT(*) FROM Pagos pg WHERE pg.id_poliza = p.id_poliza AND pg.estado_pago = 'Pendiente') AS pagos_en_verificacion,
                   (SELECT COUNT(*) FROM Siniestros sn WHERE sn.id_poliza = p.id_poliza AND sn.estado IN ('En revision', 'Aprobado', 'Reembolsado')) AS tiene_siniestro_activo
            FROM Polizas p JOIN Solicitudes s ON p.id_solicitud = s.id_solicitud JOIN Equipos e ON s.id_equipo = e.id_equipo
            WHERE e.id_cliente = %s ORDER BY p.id_poliza DESC
        """, (id_cli,))
        polizas = cursor.fetchall()
        for pol in polizas:
            pol['codigo_poliza'] = f"#{pol['numero_poliza']}"
            pol['valor_declarado'] = float(pol['valor_declarado'])
            pol['valor_asegurado'] = round(pol['valor_declarado'] * pct_cob, 2)
            pol['prima_mensual'] = round(pol['valor_declarado'] * pct_prima, 2)

        cursor.execute("""
            SELECT pg.id_pago, pg.id_poliza, pg.numero_cuota, pg.monto, pg.metodo_pago, pg.estado_pago, pg.codigo_transaccion,
                   DATE_FORMAT(pg.fecha_intento, '%d/%m/%Y %H:%i') AS fecha_pago,
                   DATE_FORMAT(pg.periodo_inicio, '%d/%m/%Y') AS periodo_inicio,
                   DATE_FORMAT(pg.periodo_fin, '%d/%m/%Y') AS periodo_fin, p.numero_poliza
            FROM Pagos pg JOIN Polizas p ON pg.id_poliza = p.id_poliza JOIN Solicitudes s ON p.id_solicitud = s.id_solicitud JOIN Equipos e ON s.id_equipo = e.id_equipo
            WHERE e.id_cliente = %s ORDER BY pg.id_pago DESC
        """, (id_cli,))
        pagos = cursor.fetchall()
        for pg in pagos:
            pg['monto'] = float(pg['monto'])
            pg['codigo_poliza'] = f"#{pg['numero_poliza']}"

        cursor.execute("""
            SELECT sn.id_siniestro, sn.id_poliza, sn.nro_denuncia_policial, sn.comisaria, sn.archivo_denuncia,
                   sn.descripcion, sn.monto_reembolso, sn.cuenta_destino, sn.estado, sn.codigo_desembolso,
                   IFNULL(sn.observaciones_admin, '') AS observaciones_admin,
                   DATE_FORMAT(sn.fecha_resolucion, '%d/%m/%Y %H:%i') AS fecha_resolucion,
                   DATEDIFF(CURDATE(), DATE(sn.fecha_reporte)) AS dias_transcurridos,
                   DATE_FORMAT(DATE_ADD(DATE(sn.fecha_reporte), INTERVAL %s DAY), '%d/%m/%Y') AS fecha_limite_reembolso,
                   p.numero_poliza, e.marca, e.modelo, e.nro_serie, e.valor_declarado
            FROM Siniestros sn JOIN Polizas p ON sn.id_poliza = p.id_poliza JOIN Solicitudes s ON p.id_solicitud = s.id_solicitud JOIN Equipos e ON s.id_equipo = e.id_equipo
            WHERE e.id_cliente = %s ORDER BY sn.id_siniestro DESC
        """, (plazo_reemb, id_cli))
        siniestros = cursor.fetchall()
        for sn in siniestros:
            sn['monto_reembolso'] = float(sn['monto_reembolso']) if sn['estado'] == 'Reembolsado' else round(float(sn['valor_declarado']) * pct_cob, 2)
            sn['codigo_poliza'] = f"#{sn['numero_poliza']}"
            sn['codigo_siniestro'] = f"#SIN-{sn['id_siniestro']:03d}"
            sn['plazo_max_dias'] = plazo_reemb

        return jsonify({"perfil": user, "equipos": equipos, "polizas": polizas, "pagos": pagos, "siniestros": siniestros, "parametros": params}), 200
    except Error as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

@app.route('/api/cliente/pagar', methods=['POST'])
def pagar_poliza():
    datos = request.json or {}
    id_poliza = datos.get('id_poliza')
    metodo = (datos.get('metodo') or 'Yape / Transferencia').strip()
    codigo_op = (datos.get('codigo_transaccion') or f"OP-{int(datetime.now().timestamp())}").strip()

    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        params = obtener_parametros_sistema(cursor)
        pct_prima = float(params.get('PORCENTAJE_PRIMA', 4.0)) / 100.0
        cursor.execute("SELECT p.id_poliza, p.estado, e.valor_declarado FROM Polizas p JOIN Solicitudes s ON p.id_solicitud = s.id_solicitud JOIN Equipos e ON s.id_equipo = e.id_equipo WHERE p.id_poliza = %s", (id_poliza,))
        pol = cursor.fetchone()
        if not pol:
            return jsonify({"error": "Póliza no encontrada."}), 404
        monto_actual = round(float(pol['valor_declarado']) * pct_prima, 2)
        cursor.execute("SELECT COUNT(*) AS total FROM Pagos WHERE id_poliza = %s AND estado_pago = 'Aprobado'", (id_poliza,))
        nro_cuota = cursor.fetchone()['total'] + 1
        hoy = date.today()
        cursor.execute("INSERT INTO Pagos (id_poliza, numero_cuota, monto, metodo_pago, estado_pago, codigo_transaccion, periodo_inicio, periodo_fin) VALUES (%s,%s,%s,%s,'Pendiente',%s,%s,%s)",
                       (id_poliza, nro_cuota, monto_actual, metodo, codigo_op, hoy, hoy + timedelta(days=30)))
        conn.commit()
        return jsonify({"mensaje": f"Pago de cuota #{nro_cuota} (S/ {monto_actual:.2f}) enviado a verificación."}), 201
    except Error as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

@app.route('/api/cliente/siniestros', methods=['POST'])
def reportar_siniestro():
    datos = request.json or {}
    id_poliza = datos.get('id_poliza')
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        params = obtener_parametros_sistema(cursor)
        pct_cob = float(params.get('PORCENTAJE_COBERTURA', 80.0)) / 100.0
        cursor.execute("SELECT p.id_poliza, p.numero_poliza, p.estado, e.valor_declarado, c.cuenta_reembolso FROM Polizas p JOIN Solicitudes s ON p.id_solicitud=s.id_solicitud JOIN Equipos e ON s.id_equipo=e.id_equipo JOIN Clientes c ON e.id_cliente=c.id_cliente WHERE p.id_poliza=%s", (id_poliza,))
        pol = cursor.fetchone()
        if not pol or pol['estado'] != 'Activa':
            return jsonify({"error": "La póliza debe estar Cubierta (Activa) para reportar un robo."}), 400
        monto_reemb = round(float(pol['valor_declarado']) * pct_cob, 2)
        cursor.execute("INSERT INTO Siniestros (id_poliza, fecha_incidente, nro_denuncia_policial, comisaria, archivo_denuncia, descripcion, monto_reembolso, cuenta_destino, estado) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,'En revision')",
                       (id_poliza, datos.get('fecha_incidente'), datos.get('nro_denuncia_policial'), datos.get('comisaria'), datos.get('archivo_denuncia', 'Denuncia.pdf'), datos.get('descripcion'), monto_reemb, datos.get('cuenta_destino') or pol['cuenta_reembolso']))
        id_sin = cursor.lastrowid
        conn.commit()
        return jsonify({"mensaje": f"Siniestro #SIN-{id_sin:03d} registrado por S/ {monto_reemb:.2f}."}), 201
    except Error as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

@app.route('/api/admin/resumen', methods=['GET'])
def admin_resumen():
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        params = obtener_parametros_sistema(cursor)
        cursor.execute("SELECT COUNT(*) AS total FROM Usuarios WHERE rol='Cliente' AND estado='Activo'")
        est = cursor.fetchone()['total']
        cursor.execute("SELECT COUNT(*) AS total FROM Solicitudes WHERE estado='Pendiente'")
        sol = cursor.fetchone()['total']
        cursor.execute("SELECT COUNT(*) AS total FROM Polizas WHERE estado='Activa'")
        pol = cursor.fetchone()['total']
        cursor.execute("SELECT COUNT(*) AS total FROM Siniestros WHERE estado IN ('En revision','Aprobado')")
        sin = cursor.fetchone()['total']
        return jsonify({"kpis": {"estudiantes_activos": est, "solicitudes_pendientes": sol, "polizas_activas": pol, "siniestros_pendientes": sin}, "parametros": params}), 200
    except Error as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

@app.route('/api/admin/solicitudes', methods=['GET'])
def ver_solicitudes_pendientes():
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        params = obtener_parametros_sistema(cursor)
        pct_prima = float(params.get('PORCENTAJE_PRIMA', 4.0)) / 100.0
        pct_cob = float(params.get('PORCENTAJE_COBERTURA', 80.0)) / 100.0
        cursor.execute("""
            SELECT s.id_solicitud, s.estado, s.ruta_foto_evidencia, IFNULL(s.observaciones, '') AS observaciones,
                   e.tipo_dispositivo AS tipo_equipo, e.marca, e.modelo, e.nro_serie,
                   DATE_FORMAT(e.fecha_compra, '%d/%m/%Y') AS fecha_compra,
                   DATEDIFF(DATE(s.fecha_solicitud), e.fecha_compra) AS dias_boleta,
                   e.valor_declarado, c.nombre_completo, c.dni, c.codigo_universitario, p.numero_poliza
            FROM Solicitudes s JOIN Equipos e ON s.id_equipo = e.id_equipo
            LEFT JOIN Clientes c ON e.id_cliente = c.id_cliente LEFT JOIN Polizas p ON s.id_solicitud = p.id_solicitud
            ORDER BY FIELD(s.estado, 'Pendiente', 'Aprobada', 'Rechazada'), s.id_solicitud DESC
        """)
        solicitudes = cursor.fetchall()
        for sol in solicitudes:
            sol['codigo_ticket'] = f"#TCK-{sol['id_solicitud']:03d}"
            sol['valor_declarado'] = float(sol['valor_declarado'])
            sol['prima_mensual'] = round(sol['valor_declarado'] * pct_prima, 2)
            sol['valor_asegurado'] = round(sol['valor_declarado'] * pct_cob, 2)
        return jsonify(solicitudes), 200
    except Error as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

@app.route('/api/admin/evaluar', methods=['POST'])
def evaluar_solicitud():
    datos = request.json or {}
    id_solicitud = datos.get('id_solicitud')
    nuevo_estado = datos.get('estado')
    motivo = (datos.get('observaciones') or '').strip()
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        params = obtener_parametros_sistema(cursor)
        pct_prima = float(params.get('PORCENTAJE_PRIMA', 4.0)) / 100.0
        pct_cob = float(params.get('PORCENTAJE_COBERTURA', 80.0)) / 100.0
        cursor.execute("SELECT s.id_solicitud, e.valor_declarado FROM Solicitudes s JOIN Equipos e ON s.id_equipo=e.id_equipo WHERE s.id_solicitud=%s", (id_solicitud,))
        sol = cursor.fetchone()
        obs_final = motivo or ('Solicitud aprobada.' if nuevo_estado == 'Aprobada' else 'Rechazada.')
        cursor.execute("UPDATE Solicitudes SET estado=%s, observaciones=%s, fecha_revision=NOW() WHERE id_solicitud=%s", (nuevo_estado, obs_final, id_solicitud))
        msg_extra = ""
        if nuevo_estado == 'Aprobada':
            cursor.execute("SELECT id_poliza FROM Polizas WHERE id_solicitud=%s", (id_solicitud,))
            if not cursor.fetchone():
                val = float(sol['valor_declarado'])
                num_pol = f"POL-{int(id_solicitud):03d}"
                hoy = date.today()
                cursor.execute("INSERT INTO Polizas (id_solicitud, numero_poliza, valor_asegurado, prima_mensual, deducible, fecha_inicio, fecha_fin, estado) VALUES (%s,%s,%s,%s,%s,%s,%s,'Pendiente de pago')",
                               (id_solicitud, num_pol, round(val*pct_cob, 2), round(val*pct_prima, 2), round(val*(1-pct_cob), 2), hoy, hoy+timedelta(days=30)))
                msg_extra = f" Póliza #{num_pol} emitida."
        conn.commit()
        return jsonify({"mensaje": f"Solicitud #TCK-{int(id_solicitud):03d} {nuevo_estado}.{msg_extra}"}), 200
    except Error as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

@app.route('/api/admin/polizas', methods=['GET', 'POST'])
def admin_polizas():
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        params = obtener_parametros_sistema(cursor)
        pct_prima = float(params.get('PORCENTAJE_PRIMA', 4.0)) / 100.0
        pct_cob = float(params.get('PORCENTAJE_COBERTURA', 80.0)) / 100.0
        if request.method == 'GET':
            cursor.execute("""
                SELECT p.id_poliza, p.id_solicitud, p.numero_poliza, p.estado,
                       DATE_FORMAT(p.fecha_inicio, '%d/%m/%Y') AS fecha_inicio,
                       DATE_FORMAT(p.fecha_fin, '%d/%m/%Y') AS fecha_fin,
                       e.marca, e.modelo, e.nro_serie, e.valor_declarado, c.nombre_completo, c.dni
                FROM Polizas p JOIN Solicitudes s ON p.id_solicitud=s.id_solicitud
                JOIN Equipos e ON s.id_equipo=e.id_equipo JOIN Clientes c ON e.id_cliente=c.id_cliente
                ORDER BY p.id_poliza DESC
            """)
            polizas = cursor.fetchall()
            for pol in polizas:
                pol['codigo_poliza'] = f"#{pol['numero_poliza']}"
                val = float(pol['valor_declarado'])
                pol['valor_asegurado'] = round(val * pct_cob, 2)
                pol['prima_mensual'] = round(val * pct_prima, 2)
            return jsonify(polizas), 200
        datos = request.json or {}
        cursor.execute("UPDATE Polizas SET estado=%s WHERE id_poliza=%s", (datos.get('estado'), datos.get('id_poliza')))
        conn.commit()
        return jsonify({"mensaje": "Estado de póliza actualizado."}), 200
    except Error as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

@app.route('/api/admin/pagos', methods=['GET', 'POST'])
def admin_pagos():
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        if request.method == 'GET':
            cursor.execute("""
                SELECT pg.id_pago, pg.id_poliza, pg.numero_cuota, pg.monto, pg.metodo_pago, pg.estado_pago, pg.codigo_transaccion,
                       DATE_FORMAT(pg.fecha_intento, '%d/%m/%Y %H:%i') AS fecha_intento,
                       DATE_FORMAT(pg.fecha_confirmacion, '%d/%m/%Y %H:%i') AS fecha_confirmacion,
                       DATE_FORMAT(pg.periodo_inicio, '%d/%m/%Y') AS periodo_inicio,
                       DATE_FORMAT(pg.periodo_fin, '%d/%m/%Y') AS periodo_fin,
                       p.numero_poliza, c.nombre_completo, e.marca, e.modelo
                FROM Pagos pg JOIN Polizas p ON pg.id_poliza=p.id_poliza JOIN Solicitudes s ON p.id_solicitud=s.id_solicitud
                JOIN Equipos e ON s.id_equipo=e.id_equipo JOIN Clientes c ON e.id_cliente=c.id_cliente
                ORDER BY FIELD(pg.estado_pago, 'Pendiente', 'Aprobado', 'Rechazado'), pg.id_pago DESC
            """)
            pagos = cursor.fetchall()
            for pg in pagos:
                pg['monto'] = float(pg['monto'])
                pg['codigo_poliza'] = f"#{pg['numero_poliza']}"
            return jsonify(pagos), 200
        datos = request.json or {}
        id_pago = datos.get('id_pago')
        accion = datos.get('estado_pago')
        cursor.execute("SELECT id_poliza FROM Pagos WHERE id_pago=%s", (id_pago,))
        pago = cursor.fetchone()
        hoy = date.today()
        fin = hoy + timedelta(days=30)
        cursor.execute("UPDATE Pagos SET estado_pago=%s, fecha_confirmacion=NOW(), periodo_inicio=%s, periodo_fin=%s WHERE id_pago=%s", (accion, hoy, fin, id_pago))
        if accion == 'Aprobado':
            cursor.execute("UPDATE Polizas SET estado='Activa', fecha_inicio=%s, fecha_fin=%s WHERE id_poliza=%s", (hoy, fin, pago['id_poliza']))
        conn.commit()
        return jsonify({"mensaje": "Pago actualizado correctamente."}), 200
    except Error as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

@app.route('/api/admin/siniestros', methods=['GET', 'POST'])
def admin_siniestros():
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        params = obtener_parametros_sistema(cursor)
        plazo = int(params.get('PLAZO_MAX_REEMBOLSO', 14))
        pct_cob = float(params.get('PORCENTAJE_COBERTURA', 80.0)) / 100.0
        if request.method == 'GET':
            cursor.execute("""
                SELECT sn.id_siniestro, sn.id_poliza, sn.nro_denuncia_policial, sn.comisaria, sn.archivo_denuncia,
                       sn.monto_reembolso, sn.cuenta_destino, sn.estado, sn.codigo_desembolso,
                       DATEDIFF(CURDATE(), DATE(sn.fecha_reporte)) AS dias_transcurridos,
                       p.numero_poliza, c.nombre_completo, e.marca, e.modelo, e.nro_serie, e.valor_declarado
                FROM Siniestros sn JOIN Polizas p ON sn.id_poliza=p.id_poliza JOIN Solicitudes s ON p.id_solicitud=s.id_solicitud
                JOIN Equipos e ON s.id_equipo=e.id_equipo JOIN Clientes c ON e.id_cliente=c.id_cliente
                ORDER BY FIELD(sn.estado, 'En revision', 'Aprobado', 'Reembolsado', 'Rechazado'), sn.id_siniestro DESC
            """)
            siniestros = cursor.fetchall()
            for sn in siniestros:
                sn['monto_reembolso'] = float(sn['monto_reembolso']) if sn['estado'] == 'Reembolsado' else round(float(sn['valor_declarado']) * pct_cob, 2)
                sn['codigo_siniestro'] = f"#SIN-{sn['id_siniestro']:03d}"
                sn['codigo_poliza'] = f"#{sn['numero_poliza']}"
                sn['plazo_max_dias'] = plazo
            return jsonify(siniestros), 200
        datos = request.json or {}
        id_sin = datos.get('id_siniestro')
        estado = datos.get('estado')
        cod = (datos.get('codigo_desembolso') or f"REEMB-{int(datetime.now().timestamp())}").strip()
        obs = (datos.get('observaciones_admin') or 'Procesado por administración.').strip()
        cursor.execute("SELECT sn.id_poliza, e.valor_declarado FROM Siniestros sn JOIN Polizas p ON sn.id_poliza=p.id_poliza JOIN Solicitudes s ON p.id_solicitud=s.id_solicitud JOIN Equipos e ON s.id_equipo=e.id_equipo WHERE sn.id_siniestro=%s", (id_sin,))
        sin = cursor.fetchone()
        monto_calc = round(float(sin['valor_declarado']) * pct_cob, 2)
        cursor.execute("UPDATE Siniestros SET estado=%s, monto_reembolso=%s, codigo_desembolso=%s, observaciones_admin=%s, fecha_resolucion=NOW() WHERE id_siniestro=%s",
                       (estado, monto_calc, cod if estado == 'Reembolsado' else None, obs, id_sin))
        if estado == 'Reembolsado':
            cursor.execute("UPDATE Polizas SET estado='Cancelada' WHERE id_poliza=%s", (sin['id_poliza'],))
        conn.commit()
        return jsonify({"mensaje": f"Siniestro #SIN-{int(id_sin):03d} actualizado a {estado}."}), 200
    except Error as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

@app.route('/api/admin/estudiantes', methods=['GET', 'POST'])
def admin_estudiantes():
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        if request.method == 'GET':
            cursor.execute("""
                SELECT u.id_usuario, u.correo_universitario, u.estado, c.nombre_completo, c.dni, c.codigo_universitario, c.telefono, c.cuenta_reembolso,
                       (SELECT COUNT(*) FROM Equipos e WHERE e.id_cliente=c.id_cliente) AS total_equipos,
                       (SELECT COUNT(*) FROM Polizas p JOIN Solicitudes s ON p.id_solicitud=s.id_solicitud JOIN Equipos e ON s.id_equipo=e.id_equipo WHERE e.id_cliente=c.id_cliente AND p.estado='Activa') AS polizas_activas
                FROM Usuarios u JOIN Clientes c ON u.id_cliente=c.id_cliente WHERE u.rol='Cliente' ORDER BY u.id_usuario DESC
            """)
            return jsonify(cursor.fetchall()), 200
        datos = request.json or {}
        cursor.execute("UPDATE Usuarios SET estado=%s WHERE id_usuario=%s AND rol='Cliente'", (datos.get('estado'), datos.get('id_usuario')))
        conn.commit()
        return jsonify({"mensaje": "Estado del estudiante actualizado."}), 200
    except Error as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

@app.route('/api/admin/catalogo', methods=['POST', 'DELETE'])
def admin_catalogo():
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        if request.method == 'POST':
            datos = request.json or {}
            if datos.get('accion') == 'parametros':
                cob_f = float(datos.get('PORCENTAJE_COBERTURA', 80))
                pri_f = float(datos.get('PORCENTAJE_PRIMA', 4))
                dias_i = int(datos.get('DIAS_MAX_BOLETA', 30))
                cob_s = str(int(cob_f) if cob_f.is_integer() else cob_f)
                pri_s = str(int(pri_f) if pri_f.is_integer() else pri_f)
                cursor.execute("UPDATE Parametros_Sistema SET valor=%s WHERE clave='PORCENTAJE_COBERTURA'", (cob_s,))
                cursor.execute("UPDATE Parametros_Sistema SET valor=%s WHERE clave='PORCENTAJE_PRIMA'", (pri_s,))
                cursor.execute("UPDATE Parametros_Sistema SET valor=%s WHERE clave='DIAS_MAX_BOLETA'", (str(dias_i),))
                cursor.execute("""
                    UPDATE Polizas p JOIN Solicitudes s ON p.id_solicitud=s.id_solicitud JOIN Equipos e ON s.id_equipo=e.id_equipo
                    SET p.valor_asegurado = ROUND(e.valor_declarado * (%s / 100.0), 2),
                        p.prima_mensual = ROUND(e.valor_declarado * (%s / 100.0), 2),
                        p.deducible = ROUND(e.valor_declarado * ((100.0 - %s) / 100.0), 2)
                    WHERE p.estado != 'Cancelada'
                """, (cob_f, pri_f, cob_f))
                cursor.execute("UPDATE Pagos pg JOIN Polizas p ON pg.id_poliza=p.id_poliza SET pg.monto=p.prima_mensual WHERE pg.estado_pago='Pendiente'")
                cursor.execute("UPDATE Siniestros sn JOIN Polizas p ON sn.id_poliza=p.id_poliza SET sn.monto_reembolso=p.valor_asegurado WHERE sn.estado IN ('En revision','Aprobado')")
                conn.commit()
                return jsonify({"mensaje": f"Reglas actualizadas ({cob_s}% cobertura, {pri_s}% cuota, {dias_i} días) en todo el sistema."}), 200
            cursor.execute("INSERT INTO Catalogo_Dispositivos (tipo_dispositivo, marca, modelo, activo) VALUES (%s,%s,%s,1)",
                           (datos.get('tipo_dispositivo', 'Celular'), datos.get('marca'), datos.get('modelo')))
            conn.commit()
            return jsonify({"mensaje": "Modelo agregado al catálogo."}), 201
        cursor.execute("UPDATE Catalogo_Dispositivos SET activo=0 WHERE id_catalogo=%s", (request.args.get('id_catalogo'),))
        conn.commit()
        return jsonify({"mensaje": "Modelo retirado del catálogo."}), 200
    except Error as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
