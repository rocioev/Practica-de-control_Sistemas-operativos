
![Bash](https://img.shields.io/badge/Bash-%23121011.svg?logo=gnu-bash&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Last commit](https://img.shields.io/github/last-commit/rocioev/Practica-de-control_Sistemas-operativos)
![Repo size](https://img.shields.io/github/repo-size/rocioev/Practica-de-control_Sistemas-operativos)
![WSL](https://img.shields.io/badge/WSL-Compatible-0078D6?logo=windows&logoColor=white)

# Simulador en Bash: FCFS/SJF + Paginación + Segunda Oportunidad (Clock)

Práctica de la asignatura **Sistemas Operativos** (1º de Grado en Ingeniería Informática, Universidad de Burgos).  
Implementa en **Bash** una simulación de **planificación de procesos** (FCFS/SJF) y **gestión de memoria por paginación**, con **reemplazo de páginas por Segunda Oportunidad (Clock)** y soporte de **memoria continua y reubicable**. 

**Autora:** Rocío Esteban Valverde  

---

## ✨ Características

- **Planificación de CPU (no apropiativa)**:
  - **FCFS/FIFO**: ejecuta primero el proceso que llega antes. 
  - **SJF**: ejecuta el proceso con menor tiempo estimado de ejecución. 
- **Memoria por paginación**:
  - Memoria dividida en **marcos** y divididos en **páginas** del mismo tamaño.
  - Cálculo de página a partir de dirección: `página = dirección / tamaño_página`. 
- **Reemplazo de páginas: Segunda Oportunidad (Clock)**:
  - Bit de referencia por marco, rotación de puntero tipo “reloj” y segunda oportunidad cuando el bit está a 1. 
- **Memoria continua y reubicable**:
  - Los procesos ocupan un **hueco contiguo**; si hay espacio total suficiente pero fragmentado, se realiza **reubicación**. 
- **Ejecución orientada a eventos**:
  - La simulación se detiene en eventos relevantes (llegadas, fin de proceso, fallos de página, reubicación…) y muestra el estado. 
- **Informes y visualización**:
  - **Banda de memoria** y **banda de tiempo**, tablas de procesos, cola de ejecución, resumen de marcos/bit de referencia, etc. 
  - Generación de `informeCOLOR.txt` e `informeBN.txt` con la ejecución completa (formato similar al mostrado por pantalla). 
  
## 🧩 Algoritmos y conceptos implementados

- **FCFS (First-Come, First-Served)**: método sencillo y justo; puede penalizar si un proceso largo bloquea CPU.   
- **SJF (Shortest Job First)**: favorece tiempos medios menores si se conoce/estima duración; puede ser injusto con procesos largos.   
- **Paginación**: páginas ↔ marcos; tabla de páginas y lista de marcos libres.   
- **Segunda Oportunidad (Clock)**: FIFO con bit de referencia y puntero circular (“reloj”) para mejorar eficiencia.   

---

## ✅ Requisitos

- **Linux + Bash** (ejecución desde terminal). 
- Terminal con soporte **ANSI** (para colores).
- (Opcional) **WSL** si estás en Windows.

---

## 🚀 Cómo ejecutar

> El repositorio está organizado con el script en `Script/`.

1) Clona el repositorio y entra en la carpeta:
```bash
git clone https://github.com/rocioev/Practica-de-control_Sistemas-operativos.git
cd Practica-de-control_Sistemas-operativos/Script
```

2.  Da permisos de ejecución:

```bash
chmod +x ./FCFSSJF_SO.sh
```

3.  Ejecuta:

```bash
./FCFSSJF_SO.sh
```

Durante la ejecución podrás:

*   Consultar la ayuda.
*   Elegir el algoritmo de planificación (**FCFS** o **SJF**).
*   Seleccionar el modo de entrada de datos (manual, desde fichero, último, por defecto, rangos/aleatorio…). 

***

## 🗂️ Estructura del proyecto

```text
Script/
├─ FCFSSJF_SO.sh
└─ datosScript/
   ├─ ayuda/
   │  └─ ayuda.txt
   ├─ datos/
   │  ├─ datos.txt
   │  └─ datos_ejemplo.txt
   ├─ rangos/
   │  ├─ datosrangos.txt
   │  ├─ rangos.txt
   │  └─ rang_ejemplo.txt
   └─ informes/
      ├─ informeBN.txt
      ├─ informeCOLOR.txt
      ├─ informes_ej_fcfs/
      │  ├─ informeBN.txt
      │  └─ informeCOLOR.txt
      └─ informes_ej_sjf/
         ├─ informeBN.txt
         └─ informeCOLOR.txt
```

**¿Qué es cada cosa?**

*   `FCFSSJF_SO.sh`: script principal.
*   `datosScript/ayuda/ayuda.txt`: texto de ayuda.
*   `datosScript/datos/`: ficheros de datos (incluye `datos_ejemplo.txt`).
*   `datosScript/rangos/`: ficheros para generación por rangos (incluye `rang_ejemplo.txt`).
*   `datosScript/informes/`: informes por defecto y ejemplos ya generados.

***

## 🧾 Formato de datos

Los datos describen:

*   Parámetros del sistema: **memoria total**, **tamaño de página**, y por tanto **número de marcos**. 
*   Lista de procesos con:
    *   Identificador (`P01`, `P02`, …)
    *   **Tiempo de llegada**
    *   **Marcos** que ocupa el proceso
    *   Lista de **direcciones**; el script deriva la **página** asociada a cada dirección. 

En el enfoque del ejemplo del informe, el **tiempo de ejecución** coincide con el número de direcciones (una dirección por unidad de tiempo). 

***

## 👀 Qué verás durante la simulación

En cada parada por evento se muestran:

*   Instante `T=...` y lista de eventos.
*   Tabla de procesos (tiempos, estado, posición en memoria…).

*   Cola de ejecución.
*   Resumen de marcos (bit de referencia, página residente).
*   **Banda de memoria** y **banda de tiempo** (con páginas ejecutadas). 

También puede aparecer:

*   Resumen de fallos de página por proceso y puntero del reloj. 
*   Pantalla de **reubicación** con estado de memoria PRE/POST. 

***

## 🖨️ Informes generados

El script puede generar (y/o sobrescribir según se configure):

*   `datosScript/informes/informeCOLOR.txt`: ejecución completa con colores. 
*   `datosScript/informes/informeBN.txt`: ejecución completa en blanco y negro. 

***

## 🛠️ Notas sobre implementación (resumen)

El script se organiza en dos bloques principales:

1.  **Recogida/creación de datos** (manual, fichero, rangos, etc.).
2.  **Ejecución**: gestión de procesos + gestión de memoria + volcado/visualización. 

Durante el desarrollo se hicieron mejoras como:

*   Modularización con funciones y reducción de complejidad.
*   Cálculo automático del tamaño de unidad en barras (tiempo/memoria) según el dato más largo.
*   Ajustes de alineado y formato en tablas e informes. 

***

## 🧪 Ejemplo

En el informe se incluye un ejemplo completo (resuelto a mano y ejecutado con script) que cubre:

*   Procesos que llegan con la CPU ocupada
*   Espera por falta de marcos
*   Reubicación por fragmentación
*   Fallos de página y comportamiento del reloj
*   Comparativa FCFS vs SJF en tiempos medios 
***

## 🙌 Créditos / Base de partida

Este trabajo tomó como referencia prácticas anteriores (citadas también en la bibliografía del informe):

*   `P - 00282 – FCFS-SJF-PagReloj-C-R-SN`
*   `P - 01690 – FCFS-SJF-Pag-NFU-NC-R` 

***

## 📚 Contexto académico

Práctica final de la asignatura Sistemas Operativos, Grado en Ingeniería Informática, Universidad de Burgos.
Orientada a afianzar conceptos de:

*   Planificación de procesos
*   Memoria virtual por paginación
*   Algoritmos de reemplazo de página (Clock / Segunda Oportunidad)
*   Trabajo en Bash/Linux 

**Autora:** Rocío Esteban Valverde  
**Contacto:** rocio.ev.002@gmail.com

***

## 📄 Licencia

Repositorio con fines educativos. Si reutilizas el código, menciona la autoría y el contexto académico.

