# Chat Grupal Distribuido (Erlang)

Chat de consola en Erlang donde varios nodos se descubren automáticamente en la red local
mediante *beacons* UDP y se intercambian mensajes usando la distribución nativa de Erlang.

## Estructura

| Archivo | Descripción |
|---|---|
| `main.erl` | Punto de entrada. Configura la cookie, inicia el núcleo, el beacon y la interfaz. |
| `chat_core.erl` | Proceso registrado como `chat`. Recibe/reenvía mensajes a los demás nodos y mantiene la lista de pares (descarta los que no se ven hace más de 15 s). |
| `chat_ui.erl` | Interfaz de consola: pide el nombre de usuario y lee mensajes. `/salir` termina el nodo. |
| `rbeacon.erl` | Descubrimiento por UDP broadcast en el puerto **8000**: envía `announcement` cada 1 s y avisa a `chat` cuando recibe uno. |

## Requisitos

- Erlang/OTP (probado con OTP 29) con `erl` y `erlc` en el `PATH`.

## Compilar

Desde la carpeta del proyecto:

```bash
erlc chat_core.erl chat_ui.erl main.erl rbeacon.erl
```

> En PowerShell `erlc *.erl` **no funciona** (PowerShell no expande el `*` para programas externos y da `*.erl: no such file or directory`). Usá la lista de archivos de arriba o `erlc (Get-ChildItem *.erl)`.
>
> Estos comandos se escriben en la terminal (PowerShell/cmd), **no** dentro del shell de Erlang (`1>`). Si entraste al shell por error, salí con `q().`

Esto genera los archivos `.beam` (ya vienen incluidos, pero conviene recompilar si se modifica el código).

## Ejecutar

Abrir **una terminal por cada participante** y en cada una lanzar un nodo con nombre corto distinto.
Los nombres reconocidos para el autodescubrimiento son `nodo1`, `nodo2`, `nodo3` y `chat`:

```bash
erl -sname nodo1 -setcookie lenguajestup2026 -noshell -s main start
```

```bash
erl -sname nodo2 -setcookie lenguajestup2026 -noshell -s main start
```

```bash
erl -sname nodo3 -setcookie lenguajestup2026 -noshell -s main start
```

Luego:

1. Ingresar un nombre de usuario cuando se pida.
2. Escribir mensajes y presionar Enter; aparecen en las demás terminales como `[usuario]: mensaje`.
3. Escribir `/salir` para cerrar el nodo.

Notas:

- `-sname` es **obligatorio**: el nodo debe estar en modo distribuido (si no, `erlang:set_cookie/2` falla).
- `-noshell` evita que el shell de Erlang compita con el chat por la entrada de teclado.
- Alternativa con shell interactivo: `erl -sname nodo1` y luego `main:start().` (la entrada puede mezclarse con el shell).
- Si aparece `[rbeacon] Puerto en uso por otro nodo local; operando en modo emisor.` es normal al correr varios nodos en la misma máquina (en Windows sólo uno puede escuchar el puerto 8000).
- Puede ser necesario permitir `erl.exe` / `epmd.exe` en el firewall de Windows.

## Chatear entre PCs distintas (misma red)

1. **Todos deben tener la misma versión del código** (copiar los `.erl`, recompilar).
2. Usar `-name` con la **IP de cada PC** (se ve con `ipconfig`, "Dirección IPv4"):

```bash
erl -name nodo2@192.168.1.10 -setcookie lenguajestup2026 -noshell -s main start
```

```bash
erl -name nodo3@192.168.1.20 -setcookie lenguajestup2026 -noshell -s main start
```

   Todos los participantes deben usar `-name` (no se pueden mezclar `-name` y `-sname`).
3. En el firewall de Windows permitir `erl.exe` y `epmd.exe` en redes **privadas** (o aceptar el aviso la primera vez). Usan UDP 8000, TCP 4369 y puertos TCP dinámicos.
4. Las dos PCs tienen que estar en la misma red (el broadcast UDP no cruza routers, y muchas redes públicas/de facultad aíslan a los clientes).

## Cómo funciona

1. `rbeacon` emite un broadcast UDP cada segundo con el texto `announcement:<nombre del nodo>`.
2. Al recibir un beacon, `chat_core` hace `net_adm:ping` al nodo anunciado y además a `nodo1`, `nodo2`, `nodo3` y `chat` del mismo host.
3. Cada mensaje escrito se envía a `{chat, Nodo}` en todos los nodos conectados.
4. Cada 2 s se hace ping a los nodos conectados y se eliminan los pares inactivos (> 15 s).

## Limitaciones conocidas

- En una misma PC, sólo un nodo puede escuchar el puerto UDP 8000; los demás sólo emiten. Por eso, entre nodos de la misma PC, se descubren por los nombres fijos `nodo1`, `nodo2`, `nodo3` y `chat`.
