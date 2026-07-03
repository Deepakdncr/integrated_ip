import psycopg2
conn=psycopg2.connect(dbname='memory_aide', user='postgres', password='Deepak', host='localhost', port='5432')
cur=conn.cursor()
cur.execute("DELETE FROM device_status WHERE user_id != 'test_user' AND device_id='ESP32-001'")
conn.commit()
