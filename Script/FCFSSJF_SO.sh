#!/usr/bin/env bash

#Cabecera del script
#  @Nombre del programa: FCFSSJF_SO.sh
#  @descripción: Simulación del funcionamiento de los algoritmos de gestion de memoria y reemplazo de paginas, FCFS/SJF, segunda oportunidad 
#  @autor: Rocío Esteban Valverde
#  @Fecha: 8-1-2023
#  @version:  1.0

# Des: configura los ajustes necesarios para que el programa funcione correctamente, esto es variables globales, ajustes para los informes
preparativos(){
	# Declaramos variables globales
	variablesGlobales

	if [ ! -d "./$CARPETA_INFORMES" ]; then
		mkdir "./$CARPETA_INFORMES"
	fi
	if [ ! -d ./$CARPETA_DATOS ]; then
		mkdir "./$CARPETA_DATOS"
	fi
	if [ ! -d ./$CARPETA_RANGOS ]; then
		mkdir "./$CARPETA_RANGOS"
	fi

	#Comprobar quue existen los archivos y directorios que necesitamos o crearlos
	exec 3>&1 4>&2 #guardamos los descriptores
	trap ' final_interrupcion ' 0 1 2 3 15 SIGTSTP
	# Ajustes para crear los informes, permite redirigir el stdout a ficheros además de la salida estandar.
	exec 1> >(tee -a "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE" "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE" )

	# exec 2> >(tee -a errr.txt) 	#por si se quieren guardar los errores para revisarlos

	#añadir fecha y hora a los informes
	fecha=$(date +%d/%m/%y_%H:%M)
	echo "$fecha" | tee "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE" > "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"
}

# des: declaración e inicialización de Variables y vectores
#Cada vez que se dice que una variable ha sido utilizada en X funcion,
#quiere decir que se utiliza por primera vez en esa funcion, luego puede utilizarse en más partes del programa
# (más variables en la funcion ejecucion, esas serían globales a la ejecución pero no son neceraias para la recogida de datos y por eso no están aquí)
variablesGlobales(){

	#ESENCIALES
	#Utilizada en todo el programa, son los Procesos, (empiezan desde el 0)
	p=0;		#plan: hacer p local donde se use							
	#Utilizada en todo el programa, es el algoritmo usado (FCFS/SJF)
	algoritmoOrdenacion="-";
	#Utilizada en todo el programa, es el Tamaño de la memoria total
	tamMem="-";							
	#Utilizada en todo el programa, es el tamaño de página
	tamPag="-";
	#Utilizada en todo el programa, es el número de marcos que hay en la memoria
	marcosTotales="-";
	#Utilizado en la todo el programa, es el número de procesos introducidos y con los que trabjará el programa.
	numProcesos="";

	##VECTORES que donde se almacenan los datos esenciales de cada proceso.
	#vector que almacena las Referencias de cada proceso
	Ref=()
	#Vector que recoge los timepos de llegada
	tiempoLlegada=();
	#Vector que recoge los tiempos de ejecución
	tiempoEjec=();
	#Vector que guarda el número de marcos de cada proceso (antes #Vector que recoge los tamaños mínimos estructurales)
	nMarcos=();
	#Vector que recoge las direcciones de cada proceso
	declare -gA directions
	#Vector que recoge las paginas(calculadas a partir de las direcciones) de cada proceso
	declare -g -A pagFichero


	##Vectores que almacenan datos de los procesos durante la ejecución de los algoritmods.
	tiempoEspera=()				# tiempo que pasa desde que el proceso llega hasta que entra en ejecución # de momento el equivalente es helsinki[]
	tiempoRetorno=() 			# tiempo que pasa desde que el proceso llega al sistema hasta que finaliza su ejecución # equivale a duración y a oslo¿?
	tiempoRestanteEj=()			# tiempo que queda hasta que el proceso que está ejecutandose termine # equivalente estocolmo[]
	marcoInicial=()				# primer marco que ocupa un proceso
	marcoFinal=()				# último marco que ocupa un proceso
	estado=() 					# puede ser: "Fuera de sistema" "En espera" "En memoria" "En ejecución" "Finalizado"

	#vector utilizado en los ImprimeProcesos, indica el número de epacios que ocupa cada columna
	declare -gA cols=( [Ref]=3 [Tll]=3 [Tej]=3 [nMar]=4 [Tesp]=4 [Tret]=4 [Trej]=4 [Mini]=4 [Mfin]=4 [Estado]=-16 )

	##Otros vectores útiles
	#Vector que recoge el número de páginas que tiene cada proceso, que es el mismo numero que el tiempo ejecucion.
	npagsProcesos=();
	#Utilizado en varias funciones para colorear los procesos
	colorjastag=();
	#Vector que almacena los procesos en un determnado orden.
	ordenados=();
	reordenados=(); 					# utilizado en reordenacion_colaEjecucion, tb almacena los procesos pero en otro orden que oredenados 
	
	#Globales generales
	anchura=`tput cols`;				#anchura de pantalla (columnas), 
	((anchura--))						# restamos uno para que no se pinten cosas en la última columna en las fucniones que  tienen en cuenta la anchura
	trap 'anchura=`tput cols`; ((anchura--))' WINCH 	##cada vez que reajustamos el ancho de la pantalla se ejecutan esos comandos
	
	#OPCIONES, variables que guardan elecciones del usuario
	menu=0;								#Utilizada en la función menuinicio, para elegir el algoritmo o la ayuda
	# introdatos=0;						#Utilizada en la función datos, para elegir el método de introduccion de datos
	modoEjecucion=0						#Utilizada en la función pideModoEjecucion

	llegados=0;							#utilizado en la función media, indica el número de procesos que ya han llegado

	# Variables que puede personalizar el programador
	CARPETA_DATOS="datosScript/datos"
	CARPETA_RANGOS="datosScript/rangos"
	nomFicheroDatos="datos.txt" 				#provisional, da igual el que se ponga.
	nomFicheroRangos="datosrangos.txt" 			#provisional, da igual el que se ponga.
	FICHERO_DATOS_ESTANDAR="datos.txt" # "ultimaejecucion.txt" #
	FICHERO_RANGOS_ESTANDAR="datosrangos.txt" # "ultimaejecucion.txt" #
	CARPETA_INFORMES="datosScript/informes"
	INFORMECOLOR_NOMBRE="informeCOLOR.txt"
	INFORMEBN_NOMBRE="informeBN.txt"
	AYUDA_RUTA="./datosScript/ayuda/ayuda.txt"
	
    readonly maximoProcesos=99                     # Número máximo de procesos que acepta el script. (El primer proceso el el 1)
	readonly numeroMaximo=$(( 9223372036854775807 / (1 + maximoProcesos) ))
                                                    # El número máximo que soporta Bash es 9223372036854775807
                                                    # Esta variable calcula el número máximo soportado por el script despejando NM de la ecuación:
                                                    # NM      + P                  * NM                  = 9223372036854775807
                                                     # TLegada + Número de procesos * Tiempo de ejecución = 9223372036854775807
                                                    # Así nunca se va a producir overflow. Da igual lo grandes que se intenten hacer los números.
                                                    # Aunque probablemente nadie intente meter números tan grandes -_-
}

##Funciones##############################
###################################

####Funciones de recogida de datos############################3

# des: primera pantalla del programa, contiene información como copyright, creditos, algoritmo, autor...
cabeceraPrograma(){			#plan: poner esto en funcion del ancho de pantalla.
	
		{
	echo "############################################################"
	echo "#                                                          #"
	echo "#                   INFORME DE PRÁCTICA                    #"
	echo "#               GESTIÓN DE MEMORIA VIRTUAL                 #"
	echo "#       ———————————————————————————————————————————        #"
	echo "#                                                          #"
	echo "############################################################"
	echo "" 
	} | tee -a "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE" >> "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"

	clear
	echo -e "\e[1;36m############################################################\e[0m"	
	echo -e "\e[1;36m#\e[0m                    © Creative Commons                    \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m                   BY - Atribución (BY)                   \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m                 NC - No uso Comercial (NC)               \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m                SA - Compartir Igual (SA)                 \e[1;36m#\e[0m"
	echo -e "\e[1;36m############################################################\e[0m"
	echo -e "\e[1;36m#\e[0m                        Créditos:                         \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m       LRU 1º: Ruben Uruñuela, Alejandro caballero        \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m          LRU 2º: Daniel Delgado, Ruben Marcos            \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m         LRU 3º: Daniel Mellado, Noelia Ubierna           \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m LRU 4º: Fernando Antón Ortega & Daniel Beato de la Torre \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m              Reloj: Ismael Franco Hernando               \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m  Reloj: Luis Miguel Agüero Hernando, Alberto Diez Busto  \e[0m\e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m               NFU: Catalin Andrei, Cacuci                \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m                                                          \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m   Algoritmo de gestión de procesos:\e[1;34m  FCFS/SJF            \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m   Gestión de memoria:\e[1;34m                PAGINACIÓN          \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m   Algoritmo de reemplazo de páginas:\e[1;34m SEGUNDA OPORTUNIDAD \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m   Memoria continua:\e[1;34m                  SÍ                  \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m   Memoria reublicable:\e[1;34m               SÍ                  \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m                                                          \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m               Autor: \e[1;33mRocío Esteban Valverde              \e[0m\e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m             Sistemas Operativos 2º Semestre              \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m       Grado en ingeniería informática (2020-2021)        \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m                                                          \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m             Tutor:\e[1;33m José Manuel Saiz Diez\e[0m                 \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m                                                          \e[1;36m#\e[0m"
	echo -e "\e[1;36m############################################################\e[0m"
	echo 
	echo -ne "Pulsa \e[1;33mINTRO\e[0m para continuar. "
	leer -r
	echo
}

# des: sale junto a los menús durante el inicio del programa
cabeceraMenus(){
	echo -e "\e[1;36m############################################################\e[0m"
	echo -e "\e[1;36m#\e[0m                                                          \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m                        \e[1;34mALGORITMO\e[0m                         \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m               \e[34mGESTIÓN DE MEMORIA VIRTUAL\e[0m                 \e[1;36m#\e[0m"
	if [ "$algoritmoOrdenacion" = "FCFS" ]; then
		echo -e "\e[1;36m#\e[0m\e[1;31m         FCFS + Paginación + Segunda Oportunidad:         \e[0m\e[1;36m#\e[0m"
	elif [ "$algoritmoOrdenacion" = "SJF" ]; then
		echo -e "\e[1;36m#\e[0m\e[1;31m          SJF + Paginación + Segunda Oportunidad:         \e[0m\e[1;36m#\e[0m"
	else
		echo -e "\e[1;36m#\e[0m\e[1;31m       FCFS/SJF + Paginación + Segunda Oportunidad:       \e[0m\e[1;36m#\e[0m"
	fi
	echo -e "\e[1;36m#\e[0m      —————————————————————————————————————————————       \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m                                                          \e[1;36m#\e[0m"
	echo -e "\e[1;36m############################################################\e[0m"
	echo ""
}

# des: última pantalla del programa, indicando que ha finalizado
cabecerafinal(){
	clear
	echo ""
	echo -e "\e[1;36m############################################################\e[0m"
	echo -e "\e[1;36m#\e[0m                                                          \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m                        \e[1;34mALGORITMO\e[0m                         \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m               \e[34mGESTIÓN DE MEMORIA VIRTUAL\e[0m                 \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m       ———————————————————————————————————————————        \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m       —————————  \e[1;35m Fin de la ejecución\e[0m  ——————————        \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m       ———————————————————————————————————————————        \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m       ————————  \e[1;31mRocío Esteban Valverde\e[0m  —————————        \e[1;36m#\e[0m"
	echo -e "\e[1;36m#\e[0m                                                          \e[1;36m#\e[0m"
	echo -e "\e[1;36m############################################################\e[0m"
	echo ""
}

# des: pregunta si ejecutar, leer la ayuda o salir.
# fucionamiento: cabecera, pregunta, loop hasta que se pulse ejeutar o salir
preguntainicio(){
	clear
	cabeceraMenus
	menu=""
	echo -e "\e[1;38;5;81m¿Desea leer el fichero de ayuda o ejecutar el algoritmo?\e[0m"
	echo ""
	echo -e "\e[1;33m	1\e[0m- Ejecutar el algoritmo"
	echo -e "\e[1;33m	2\e[0m- Visualizar la ayuda"
	echo -e "\e[1;33m	3\e[0m- Salir"
	echo ""
	echo -n "Seleccione una opción: "
	while :;do
		leer_numero_entre menu 1 3
		# En caso de que el valor devuelto por la función anterior
		case $? in
			# Valor válido
			0 )
				break
			;;
			# Valor no número natural o No se introduce nada
			1 | 2 )
				echo -n -e "\e[1;31mAviso. Introduce un número natural: \e[0m"
			;;
			# Valor demasiado grande o pequeño
			3 | 4 )
				echo -e "\e[1;31mAviso.\e[0m Pulse\e[1;33m 1\e[0m,\e[1;33m 2\e[0m o\e[1;33m 3\e[0m\e: "
			;;
		esac
	done
	echo
	clear
	if [[ $menu = 2 ]]; then
		if [[ ! -f "${AYUDA_RUTA}" ]]		 #-f --> si es un fichero ordinario  y existe
			then	# si no es un fichero ordinario
				echo "El fichero de ayuda no está disponible. Comprueba si se encuentra en \"${AYUDA_RUTA}\""
			else		# si es un fichero ordinario
				(more "${AYUDA_RUTA}")					#plan: conseguir que more se ejecute normal(que se pueda hacer scroll) y no que se imprima la ayuda y ya como si se hiciera cat.
		fi
		leer -r
		preguntainicio
	fi
	if [[ $menu = 3 ]]; then 
	exit
	fi	
}

#des: pregunta como guardar los informes y crea las carpetas necesarias
preguntaDondeGuardarInformes(){
	clear
	cabeceraMenus
	local dondeinformes=0
	local carpeta_informes_otra
	#plan: si le dan al dos mover el informe a la nueva ubicacion
	echo -e "\e[1;38;5;81m¿Dónde quieres guardar los informes?\e[0m"
	echo ""
	echo -e "\e[1;33m	1\e[0m- En el directorio estandar ($CARPETA_INFORMES)"
	echo -e "\e[1;33m	2\e[0m- En otro directorio"
	# echo -e "\e[1;33m	3\e[0m- No guardar"
	echo ""
	leer -p "Seleccione una opción: " dondeinformes
	until [[ $dondeinformes = 1 || $dondeinformes = 2 ]]; do
		echo -n -e "Por favor seleccione una opción de las dadas: "
		leer -r dondeinformes
	done
	if [[ $dondeinformes = "2" ]];then
		#pedir nombre del nuevo directorio
		echo
		echo -n "Introduce el nombre del directorio: "
		leer -p carpeta_informes_otra

		until [[ -d "./$carpeta_informes_otra" ]] && [[ ! -f "./$carpeta_informes_otra/$INFORMECOLOR_NOMBRE" ]] && [ ! -f "./$carpeta_informes_otra/$INFORMEBN_NOMBRE" ]; do
			#comprobar si el directorio existe
			if [[ ! -d "./$carpeta_informes_otra" ]]; then
				#si no existe, crearlo
				mkdir "./$carpeta_informes_otra"
				echo
				echo -e "\e[1;32mSe ha creado el directorio\e[0m \e[1;33m'$carpeta_informes_otra'\e[0m "
				echo
			fi
			
			#comprobar que el directorio no tenga informes ya
			if [[ -f "./$carpeta_informes_otra/$INFORMECOLOR_NOMBRE" ]] && [ -f "./$carpeta_informes_otra/$INFORMEBN_NOMBRE" ]; then
				#si tiene informes, preguntar si sobreescribirlos
				echo ""
				echo -e "\e[1;38;5;81mLa carpeta \e[1;33m'$carpeta_informes_otra'\e[0m\e[1;38;5;81m ya contiene informes ¿Quieres sobrescribirlos?\e[0m"
				echo ""
				echo -e "\e[1;33m	s\e[0m- Sí"
				echo -e "\e[1;33m	n\e[0m- No, elegir otro directorio"
				echo ""
				leer -p "Introduce: " dondeinformes
				until [[ $dondeinformes = "s" || $dondeinformes = "n" ]]; do
					echo -n -e "Por favor introduzca \e[1;33ms\e[0m(sí) o \e[1;33mn\e[0m(no): "
					leer -r dondeinformes
				done
				#si no hay que sobreescribir
				if [[ $dondeinformes = "n" ]]; then
					#pedir nombre de nuevo
					leer -p "Introduce el nombre del directorio: " carpeta_informes_otra
				#si se quiere sobreescribir
				else
					#eliminar los informes que había
					rm "$carpeta_informes_otra/$INFORMECOLOR_NOMBRE"
					rm "$carpeta_informes_otra/$INFORMEBN_NOMBRE"
				fi
			fi
		done
		#meter los nuevos informes a la carpeta elegida
		mv "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE" "./$carpeta_informes_otra/$INFORMECOLOR_NOMBRE"
		mv "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE" "./$carpeta_informes_otra/$INFORMEBN_NOMBRE"
		
		#establecer la nueva carpeta como la estandar
		CARPETA_INFORMES="$carpeta_informes_otra"
		echo -e "\e[1;32mSe han guardado los informes en el directorio\e[0m \e[1;33m'$CARPETA_INFORMES'\e[0m "
		sleep 2
	fi
	echo
	echo
	echo
}

#des: función que pide al usuario que escoja el algoritmo de ordenación de procesos
preguntaMetodoOrdenacion (){
	clear
	cabeceraMenus
	echo -e "\e[1;38;5;81mElige un método de ordenación de procesos:\e[0m"
	echo
	echo -e "\e[1;33m	1\e[0m.Algoritmo FCFS."
	echo -e "\e[1;33m	2\e[0m.Algoritmo SJF"
	echo ""
	echo -n "Seleccione una opción: "
	while :;do
		leer_numero_entre algoritmoOrdenacion 1 2
		# En caso de que el valor devuelto por la función anterior
		case $? in
			# Valor válido
			0 )
				break
			;;
			# Valor no número natural o No se introduce nada
			1 | 2 | 3 |4)
				echo ""
				echo -e "\e[1;31mDecídete, pulsa 1 o 2\e[0m"
				echo -n "Elige un método de ordenación: "
			;;
		esac
	done
	until [[ $algoritmoOrdenacion = "1" || $algoritmoOrdenacion = "2" ]]
	do
		echo ""
		echo -e "\e[1;31mDecídete, pulsa 1 o 2\e[0m"
		echo "Elige un método de ordenación:"
		echo -e "\e[1;33m	1\e[0m.Algoritmo FCFS."
		echo -e "\e[1;33m	2\e[0m.Algoritmo SJF"
		echo ""
	leer -p  "Inserte 1 o 2 en función de su preferencia: " algoritmoOrdenacion
	done
	echo 
	# meter en el informe la info del algoritmo elegido
	if test "$algoritmoOrdenacion" = 1
		then	algoritmoOrdenacion="FCFS"
		else	algoritmoOrdenacion="SJF"
	fi
	{
	echo  "Algoritmo de ordenación de procesos: $algoritmoOrdenacion" 
	echo "" ; } | tee -a "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE" >> "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"
	clear
}

#des: Funcion que pregunta como se introducen los datos y getsiona la llamada a otras fucniones en función de la opción seleccionada.
datos(){
	local introdatos=0;						#para elegir el método de introduccion de datos
	clear
	cabeceraMenus
	echo -e "\e[1;38;5;81m¿Cómo desea introducir los datos?\e[0m"
	echo ""
	echo -e "\e[1;33m	1\e[0m- Por teclado"
	echo -e "\e[1;33m	2\e[0m- Fichero con los datos de la última ejecución ($FICHERO_DATOS_ESTANDAR)"
	echo -e "\e[1;33m	3\e[0m- Otro fichero de datos"
	echo "	Generar aleatoriamente: "
	echo -e "\e[1;33m	4\e[0m- Introducir rangos por teclado"
	echo -e "\e[1;33m	5\e[0m- Fichero con los rangos de la última ejecución ($FICHERO_RANGOS_ESTANDAR)"
	echo -e "\e[1;33m	6\e[0m- Otro fichero de rangos"
	echo ""
	echo -n "Seleccione una opción: "
	while :;do
		leer_numero_entre introdatos 1 6
		case $? in  # En caso de que el valor devuelto por la función anterior
			0 )  # Valor válido
				break 
			;;              
			1|2|3|4 ) # Valor no número natural, o que no es ninguna opción
				echo -n "Aviso. Introduce el número correspondiente a una de las opciones: " 
			;;
		esac
	done
	echo
	#según la opción elegida
	case $introdatos in
		1)	#Por teclado
			datos_teclado
		;;
		2)	#Fichero con los datos de la última ejecución (datos.txt)
			#comprobar que el fichero existe
			local rutaFicheroDatos="./$CARPETA_DATOS/$FICHERO_DATOS_ESTANDAR"
			if [ -f "$rutaFicheroDatos" ]; then	
				datos_leerFichero
			 else
				echo -e "\e[31mNo se ha encontrado el fichero '$FICHERO_DATOS_ESTANDAR'\e[0m] "
				read -r -t 3
				datos
			fi
		;;
		3) 	#Otro fichero de datos
			preguntaqueficheroleer_datos				#<-- de aquí salen CARPETA_DATOS y nomFicheroDatos
			local rutaFicheroDatos="./$CARPETA_DATOS/$nomFicheroDatos"
			datos_leerFichero
		;;
		4|5|6) 	#DATOS ALEATORIOS
				#Introducir rangos de forma manual
				#Fichero con los rangos de la última ejecución
				#Otro fichero de rangos
			local rutaFicheroRangos="./$CARPETA_RANGOS/$FICHERO_RANGOS_ESTANDAR"
			datos_random
		;;
	esac
	clear
	imprimeDatosResumen
	{
	echo ""
	echo ""
	echo "|—————————————————————————————————————————————————————————————————————————|"
	echo ""
	echo "";} | tee -a "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE" >> "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"
	clear
}

# des: pregunta si guardar en el fichero estandar o en otro los datos que va a introducir manualmente a continuación.
#		si es en otro, pide el nombre/direccion del archivo.
#		Establece las variables nomFicheroDatos y rutaFicheroDatos o las esquivalentes de rangos.
# param: "datos" o "rangos" -> dependiendo del parametro que se le pase pide guardar datos o guardar rangos
preguntadondeGuardarDatosManuales(){
	local nombre
	local dondeguardar
	#Pregunta para los datos por teclado
	if [[ $1 = "datos" ]];then
		echo ""
		echo -e "\e[1;38;5;81m¿Dónde quiere guardar los datos?\e[0m"
		echo ""
		echo -e "\e[1;33m	1\e[0m- En el fichero estandar ($FICHERO_DATOS_ESTANDAR)"
		echo -e "\e[1;33m	2\e[0m- En otro fichero"
		echo ""
		leer -p "Seleccione una opción: " dondeguardar
		until [[ $dondeguardar = "1" || $dondeguardar = "2" ]];	do
			echo ""
			echo -e "\e[1;31mNo aporrees el teclado, elige una opción\e[0m"
			leer -p "Selecciona: " dondeguardar
		done
		case "${dondeguardar}" in
			1) #En el fichero estandar
				nomFicheroDatos="$FICHERO_DATOS_ESTANDAR"
				rutaFicheroDatos="./$CARPETA_DATOS/$nomFicheroDatos"
				;;
			2) #En otro fichero
				leer -p "Introduce el nombre que le quieres dar al fichero de datos (sin '.txt'): " nombre
				nomFicheroDatos="$nombre.txt"
				rutaFicheroDatos="./$CARPETA_DATOS/$nomFicheroDatos"
				until [[ ! -f "$rutaFicheroDatos" ]];do			
					echo -e "Ya existe un archivo con el nombre \e[1;33m'$nomFicheroDatos'\e[0m."
					echo -n -e "Introduzca un nombre diferente: "
					leer -r nombre
					nomFicheroDatos="$nombre.txt"
					rutaFicheroDatos="./$CARPETA_DATOS/$nomFicheroDatos"
				done
			;;
		esac
		
	#Pregunta para los rangos por teclado
	elif [[ $1 = "rangos" ]]; then
		echo -e "\e[1;38;5;81m¿Dónde quiere guardar los rangos?\e[0m"
		echo ""
		echo -e "\e[1;33m	1\e[0m- En el fichero estandar ($FICHERO_RANGOS_ESTANDAR)"
		echo -e "\e[1;33m	2\e[0m- En otro fichero"
		echo ""
		leer -p "Seleccione una opción: " dondeguardar
		until [[ $dondeguardar = "1" || $dondeguardar = "2" ]];	do
			echo ""
			echo -e "\e[1;31mNo aporrees el teclado, elige una opción\e[0m"
			leer -p "Selecciona: " dondeguardar
		done
		case "${dondeguardar}" in
			1) #En el fichero estandar
				nomFicheroRangos="$FICHERO_RANGOS_ESTANDAR"
				rutaFicheroRangos="./$CARPETA_RANGOS/$nomFicheroRangos"
			;;
			2) #En otro fichero
				leer -p "Introduce el nombre que le quieres dar al fichero donde se guardarán los rangos que introducirás a continuación (sin '.txt'): " nombre
				nomFicheroRangos="$nombre.txt"
				rutaFicheroRangos="./$CARPETA_RANGOS/$nomFicheroRangos"
				until [[ ! -f "$rutaFicheroRangos" ]];do			
					echo -e "Ya existe un archivo con el nombre \e[1;33m'$nomFicheroRangos'\e[0m."
					echo -n -e "Introduzca un nombre diferente: "
					leer -r nombre
					nomFicheroRangos="$nombre.txt"
					rutaFicheroRangos="./$CARPETA_RANGOS/$nomFicheroRangos"
				done
			;;
		esac
	fi
}

#Des: Función que muestra un resumen de los datos existentes hasta el momento.
#funcionamiento: ordena, imprime datos globales, imprime procesos, espera pulsar enter.
imprimeDatosResumen(){
	local p=0
	p=$(( numProcesos - 1 ))
	imprimedatosglob
	imprimeProcesos
	echo ""
	echo ""
	echo -ne " Esto es un resumen de los datos obtenidos. Pulsa \e[1;33mINTRO\e[0m para continuar "
	leer -r
	echo
}

#des: funcion que imprime un resumen de los datos del sistema, memoria.
imprimedatosglob(){
	cabeceraMenus
	# echo -e "|FCFS/SJF+Paginación+Seg.Op+M.Continua+Reubicable"
	echo -e "|Algoritmo usado:    $algoritmoOrdenacion"
	echo -e "|Memoria del Sistema:	$tamMem"
	echo -e "|Tamaño  de   Página:	$tamPag"
	echo -e "|Marcos totales de la memoria:	$marcosTotales"
}

#DES: Función que muestra en pantalla los datos de los procesos que se van introduciendo ya en orden de llegada.
#funcionamiento: ordena, asigna color, imprime
imprimeProcesos(){
	# contar el número de espacios que ocupa cada columna por si acaso
	for n in "${tiempoLlegada[@]}"; do [[ ${#n} > ${cols[Tll]} ]] && cols[Tll]=${#n}; done
	for n in "${tiempoEjec[@]}"; do [[ ${#n} > ${cols[Tej]} ]] && cols[Tej]=${#n} ; done
	for n in "${nMarcos[@]}"; do [[ ${#n} > ${cols[nMar]} ]] && cols[nMar]=${#n} ;done 

	local ord=0
	local impaginillas=0 			#direcciones de pagina
	local contador=18;

	ordenacion
	asignaColor
	#	   " Ref Tll Tej nMar Dirección-Página"    #en %*s, * es la cantidad de espacios que ocupará la variable que sustituye a los caracteres s(ponemos 's'(string) pq cuando no hay nada escribe '-' y si pone 'd'(entero) no lo admite) 
	printf " %-*s %*s %*s %*s Dirección-Página " ${cols[Ref]} "Ref" ${cols[Tll]} "Tll" ${cols[Tej]} "Tej"  ${cols[nMar]} "nMar"
	
	for ord in "${ordenados[@]}";do 
		#Color
		echo -ne "\e[1;3${colorjastag[$ord]}m"
		#primeras 4 columnas
		printf "\n %-*s %*s %*s %*s " "${cols[Ref]}" "${Ref[$ord]}" "${cols[Tll]}" "${tiempoLlegada[$ord]}" "${cols[Tej]}" "${tiempoEjec[$ord]}" "${cols[nMar]}" "${nMarcos[$ord]}"
		contador=18
		#Color
		echo -ne "\e[0m"
		#Direcciones de página
		for (( impaginillas=0; impaginillas < npagsProcesos[ord] ; impaginillas++ ));	# a la variable donde estamos almacenando la cadena de texto le añadimos una a una las direcciones del proceso
		do	
			cols[D-P]="$( echo "${directions[$ord,$impaginillas]}-${pagFichero[$ord,$impaginillas]}" | wc -m )"
			if [[ $contador -gt $(($anchura-${cols[D-P]})) ]]; then
				printf "\n " #salto de linea
				contador=1	#reajustar el contador
			fi
			
			echo -ne "\e[0;3${colorjastag[$ord]}m${directions[$ord,$impaginillas]}-\e[0m" #la direccion va sin negrilla
			echo -ne "\e[1;3${colorjastag[$ord]}m${pagFichero[$ord,$impaginillas]}\e[0m " #la página va en negrilla

			((contador=contador+${cols[D-P]}+1))
		
		done
		#desactivar colores
		echo -ne "\e[0m"
	done
}

#Des: funcion que asigna el color a los procesos metidos hasta el momento.
#funcionamiento: utiliza < numprocesos
asignaColor(){
	local counter
	local color=1
	for (( counter = 0; counter < numProcesos ; counter++ ))
	do	
		if [[ $color -gt 6 ]]; then
			color=1
		fi
		((colorjastag[counter]=color));
		((color++))
	done
}

#Descripcion: funcion que ordena los pocesos que hay hasta el momento según su orden de llegada o menor tiempo de ejecución
#funcionamiento: utiliza <= p
ordenacion(){
	local pep=0
	local kek=0
	local jej=0

	#Se inicializa el vector de ordenacion
	for (( pep=0; pep<=$p; pep++ ));do
		ordenados[$pep]=$pep
	done
	for (( kek=1; kek<=$p; kek++ ));do
		for (( jej=0; jej <= ($p-$kek); jej++ ))
		do
			if [[ ${tiempoLlegada[${ordenados[$jej]}]} -gt ${tiempoLlegada[${ordenados[$jej+1]}]} ]];then
				aux=${ordenados[$jej]}
				ordenados[$jej]=${ordenados[$jej+1]}
				ordenados[$jej+1]=$aux
			fi
		done
	done
	for (( pep=0; pep<=$p; pep++ ));do
		reordenados[$pep]=${ordenados[$pep]}
	done
	if [ $p -eq 0 ];then
		ordenados[0]=0
	fi
}

####################################
##  ENTRADA DE DATOS POR TECLADO  ##
####################################

# des: funcion que gestiona las llamadas a otras funciones para la recogida de datos por teclado. 
#		pregunta donde guardar los datos, pide variables globales, loop de pedir los demás datos y pregunta si quiere más procesos hasta que no.
datos_teclado(){
	local newp='s'							#Utilizada en la funcion datosteclado, para comprobar si se quiere introducir o no un nuevo proceso
	local counter=0 						#contador del número de procesos que hay
	local rutaFicheroDatos="./$CARPETA_DATOS/$FICHERO_DATOS_ESTANDAR"
	p=0
	if [[ $counter == 0 ]]; then
		echo ""
		echo -e "\e[1;32mSe tomarán datos del teclado\e[0m"
		sleep 1
		clear
	fi

	preguntadondeGuardarDatosManuales "datos"
	rutaFicheroDatos="./$CARPETA_DATOS/$nomFicheroDatos"

	pidevarglob

	#loop mientras se quieran seguir metiendo procesos
	while [[ $newp = "s" ]]
	do	
		clear
		((counter++))
		numProcesos=$counter 		#pq ordenados funciona con numprocesos
		# tusa[$counter]=1

		echo "" | tee -a "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE" >> "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"
		echo "" | tee -a "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE" >> "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"
		# crear referencia proceso(empiezan desde P01)
		if [[ $counter -gt 9 ]];then 
			Ref[$p]="P$counter"					
			else
			Ref[$p]="P0$counter"
		fi
		#leemos el tiempo de llegada
		pide_llegada
		
		#pide el número de marcos de página		
		pide_nmarcos
		
		#pide las páginas y las guarda en ficheros para cada proceso
		pide_direcciones

		#CONTROLdeERRORES ################################ meter aqui control de errores

		imprimeProcesos
		((p++))	
		# clear
		#si no se supera máximo de procesos, preguntar si el usuario quiere introducir más procesos
		if [[ $p -le $maximoProcesos ]]; then
			echo "";												#aqui abajo pone (en amarillo) (s/n)
			echo -ne "\e[1;38;5;81m¿Desea introducir mas procesos?\e[0m (\e[1;33ms\e[0m/\e[1;33mn\e[0m) "
			leer newp
			until [[ $newp = "s" || $newp = "n" ]];
			do
				echo ""
				echo -ne "\e[1;31mNo aporrees el teclado, mete \e[1;33ms\e[0m o \e[1;33mn\e[0m\e[0m: "
				leer newp
			done
		fi

	done
	clear
	numProcesos=$counter
	p=$((numProcesos-1))
}

# DES: Función que pide tamaño de página y numero de marcos totales, calcula el tamaño de la memoria y imprime un resumen
pidevarglob(){
	clear
	pide_tampags
	pide_marcostotales

	tamMem=$((tamPag * marcosTotales))
	clear
	imprimedatosglob
	echo
	echo -e "\e[1;32mCon los datos introducidos el tamaño de la memoria del sistma es: $tamMem \e[0m"
	echo 
	echo -ne "Pulsa \e[1;33mINTRO\e[0m para continuar. "
	leer -r
	clear
}

# des: función que pide el tamaño de página y lo registra en el fichero de datos
pide_tampags(){
	clear
	imprimedatosglob
	echo
	echo -n "Introduce el tamaño de página (igual en todas): "
	while :;do
        leer_numero_entre tamPag 1 "$tamMem"
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "\e[1;31mIntroduce un número natural: \e[0m"
            ;;
            # Valor demasiado grande
            3 )
                echo -e "\e[1;31mEl tamaño de las páginas no puede ser mayor que el tamaño de la memoria. "
				echo -n "Introduce un nuevo tamaño de página: "
			;;
			# Valor demasiado pequeño
            4 )
                echo -e "\e[1;31mEl tamaño mínimo es 1."
				echo -n "Introduce un tamaño de página mayor que 0: "
            ;;
        esac
    done
	printf "%d\n" "$tamPag" > "$rutaFicheroDatos"
}
# des: función que pide el número de marcos totales de la memoria y lo registra en el fichero de datos
pide_marcostotales(){
	clear
	imprimedatosglob
	echo ""
	echo -n "Introduce el número de marcos totales de la memoria: "
	while :;do
        leer_numero_entre marcosTotales 1 
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "\e[1;31mIntroduce un número natural: \e[0m"
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "\e[1;31mValor demasiado grande\e[0m"
				echo "Introduce un nuevo número de marcos de la memoria: "
			;;
			# Valor demasiado pequeño
            4 )
                echo -n -e "\e[1;31mEl número de marcos debe ser mayor que 0.\e[0m"
				echo "Introduce un nuevo número de marcos que sea mayor que 0: "
            ;;
        esac
    done
	printf "%d\n" "$marcosTotales" >> "$rutaFicheroDatos"
}

# des: Función que pide el tiempo de llegada de los procesos y lo registra en el fichero de datos
pide_llegada(){
	imprimeProcesos
	echo ""
	echo -e "Tiempo de llegada de \e[1;3${colorjastag[$p]}m${Ref[$p]}\e[0m"
	echo -n "Introduce: "

	while :;do
        leer_numero tiempoLlegada[$p]
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "\e[1;31mIntroduce un número natural: \e[0m"
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "Valor demasiado grande."
				echo "Introduce un nuevo tiempo de llegada: "
			;;
        esac
    done
	echo -n "${tiempoLlegada[$p]} " >> "$rutaFicheroDatos"
	clear
}

#Función que pide el número de marcos de cada proceso y lo registra en el fichero de datos
pide_nmarcos(){
	imprimeProcesos
    echo ""
	echo "" | tee -a "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE" >> "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"

	echo -e "Número de marcos de página de \e[1;3${colorjastag[$p]}m${Ref[$p]}\e[0m"
	echo -n "Introduce: "
	while :;do
        leer_numero_entre nMarcos[$p] 1 $marcosTotales
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "\e[1;31mIntroduce un número natural: \e[0m"
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "El número de marcos debe ser menor que $marcosTotales (marcos totales): "
            ;;
			# Valor demasiado pequeño
            4 )
                echo -n -e "El número de marcos debe ser u número positivo mayor que 0: "
            ;;
        esac
    done
	echo -n "${nMarcos[$p]} " >> "$rutaFicheroDatos"
	clear	
}

# des: Función que pide las direcciones de cada proceso, calcula la página correspondiete y lo guarda en el fichero de datos elegido.
pide_direcciones(){
	clear
	imprimeProcesos

	tiempoEjec[$p]=""
	npagsProcesos[$p]=0
	local pag=0;						# para recorrer el tiempo de ejecucion del proceso e imprimir sus paginas
	local direccionleida="--"
	local masdirecciones=n

	for (( pag=0; ; pag++ ));do

		echo ""
		echo "Escribe la dirección número $pag (introduce 'x' si no quieres introducir más direcciones)"
		echo -n "Introduce: "
		while : ;do
			leer_numero direccionleida
            case $? in
                
                0 ) # Valor válido
					#guardar dirección
					directions[$p,$pag]="$direccionleida"
					echo -n "${directions[$p,$pag]} " >> "$rutaFicheroDatos"
					#calcular la página correspondiente
					pagFichero[$p,$pag]=$(( directions[$p,$pag] / "$tamPag" ))
					
					((npagsProcesos[$p]++))
					#dar valor al numero de procesos para que se muestre en pantalla
					tiempoEjec[$p]=${npagsProcesos[$p]}
					break
                ;;
                1 | 2 ) # Valor no número natural
					#comprobar si es la x que indica que no quiere meter más direcciones
                    if [ "${direccionleida}" != "x" ];then

						echo -ne "\e[1;31m Debe introducir un número natural: \e[0m"

						else   	# Si se ha introducido "x"

						#comprobar que se haya introducido al menos una dirección
						if [[ ${npagsProcesos[$p]} -eq "0" ]];then #si no hay paginas

							echo -ne "\e[1;31mTienes que introducir al menos una direccion: \e[0m"

							#si hay páginas pero el número de páginas es menor que el número de marcos
							elif [[ ${npagsProcesos[$p]} -lt ${nMarcos[$p]} ]]; then
								#preguntar si les importa desperdiciar memoria
								echo -e "\e[1;31mEl numero de direcciones es menor al número de marcos que ocupa el proceso. Se está produciendo un desperdicio de memoria.\e[0m"
								echo -e "\e[1;38;5;81m¿Quiere introducir más direcciones?\e[0m"
								echo ""
								echo -e "\e[1;33m	s\e[0m- Sí, seguir introduciendo direcciones"
								echo -e "\e[1;33m	n\e[0m- No, ya he introducido todas las direcciones que quiero"
								echo ""
								leer -p "Selecciona: " masdirecciones
								until [[ $masdirecciones = "s" || $masdirecciones = "n" ]];
								do
									echo ""
									echo -e "\e[1;31mNo aporrees el teclado, escribe 's' o 'n'\e[0m"
									leer -p "Selecciona: " masdirecciones
								done
								#si no quieren meter más direcciones 
								if [[ $masdirecciones = "n" ]];then 
									#salir del bucle
									break 2
									else
									#mensaje antes de leer direccion otra vez
									echo -ne "Intruduce la dirección número $pag: "
								fi
							#si ya hay páginas metidas y no se desperdicia memoria
							else
								#salir de los bucles de leer y meter más páginas.
								break 2
						fi
					fi
				;;
                3 ) # Valor demasiado grande
                    echo -n -e "\e[1;31m Valor demasiado grande: \e[0m"
                ;;
			esac
		done
		clear
		imprimeProcesos
	done
	echo -e "\n" >> "$rutaFicheroDatos"
	tiempoEjec[$p]=${npagsProcesos[$p]}
	clear
}

## fin entrada de datos por teclado ###############################################

# des: Busca en datosScript/datos los ficheros disponibles y da al usuario a elegir.
# Establece el contenido nomFicheroDatos a lo que haya elegido el usuario
preguntaqueficheroleer_datos(){
	local seleccion=""
	p=0

	#meter los archivos de extensión .txt del directorio en una lista
	for arch in "$CARPETA_DATOS"/*.txt ;do
		lista+=("${arch##*/}")
	done
	# Si no hay archivos en la carpeta
	if [ "${lista[0]}" == "*" ];then
		echo -e "No se ha encontrado ningún archivo de texto en la carpeta $CARPETA_DATOS."
		read -r -t 3
		datos
	fi
	
	echo -e "\e[1;38;5;81m¿De qué archivo quieres extraer los datos?\e[0m"
	echo -e "\e[1;38;5;81mEstos son los archivos disponibles:\e[0m"
	# Por cada archivo en la carpeta imprime una linea
	for archivo in ${!lista[*]};do
		echo -e "	\e[1;32m$(($archivo + 1))\e[0m- ${lista[$archivo]}"
	done
	echo -n "Selecciona: "
	while :;do
        leer_numero_entre seleccion 1 ${#lista[*]}
        # En caso de que el valor devuelto por la función anterior
        case $? in
            # Valor válido
            0 )
                break
            ;;
            # Valor no número natural
            * )
                echo -n -e "AVISO Introduce un número entre 1 y ${#lista[*]}: "
            ;;
        esac
    done
	((seleccion--))
	#Asignar nombre del fichero que se usará
	nomFicheroDatos=${lista[$seleccion]}

	rutaFicheroDatos="./$CARPETA_DATOS/$nomFicheroDatos"
	echo -e "\e[1;32mSe tomarán los datos del archivo $nomFicheroDatos\e[0m"
	sleep 1
	clear
	unset lista
}

#des: Función que lee los datos del fichero al cual se accede desde 'rutaFicheroDatos'
datos_leerFichero(){
	local maxfilas=0 				#numero de filas no vacias que tiene el fichero de datos
	declare	-gA directions
			
	#Leer datos del fichero
	tamPag=`awk "NR==1" $rutaFicheroDatos`				; #Primer dato -> Tamaño de página
	marcosTotales=`awk "NR==2" $rutaFicheroDatos`		; #Segundo dato -> Nímero de marcos de la memoria
	tamMem=$((tamPag*marcosTotales))				; #Con los datos anteriores se puede calcular el tamaño total de la memoria.
	maxfilas=`wc -l < $rutaFicheroDatos`			; #cuenta el número de líneas del fichero(el número de saltos de línea para ser exactos)
	numProcesos=$((maxfilas-2))		 				#establece el número de procesos con los que trabajará el programa
	#comprobación del numero de procesos
	if (( numProcesos > maximoProcesos )); then
		echo -e "\e[31mEl número de procesos encontrados en el fichero es mayor al máximo de procesos que permite el programa($maximoProcesos)\e[0m"
		echo "Saliendo"
		read -t 5
		exit
	fi	
	local p=0
	local leepags=0
	local counter=3
	for (( fila=3; fila <= maxfilas ; fila++ )) #recorremos los procesos que van de la linea 3 a la última
	do
		#leemos el primer elemento de la fila, el tiempo de llegada del proceso
		tiempoLlegada[$p]=`awk "NR==$fila" $rutaFicheroDatos |  cut -d ' ' -f 1`
		#leemos el segundo elemento de la fila, el numero de marcos del proceso
		nMarcos[$p]=`awk "NR==$fila" $rutaFicheroDatos |  cut -d ' ' -f 2`

		cuentapaginas #de esta función sale $mayorNpags

		#el tiempo de ejecución de los procesos es igual al numero de paginas (suponemos que cada pagina tarda en ejecutarse una unidad de tiempo)
		tiempoEjec[$p]=${npagsProcesos[$p]} 
		tiempoEjec[$p]=${tiempoEjec[$p]} #a ver si quito el dichoso tiempoEjec
		leepags=0
		for (( i=3 ; i <= maxPalabras; i++ ))
			do	
			#extraemos todas las direcciones de cada proceso y las guardamos en la matriz 
			directions[$p,$leepags]=`awk "NR==$fila" $rutaFicheroDatos | cut -d ' ' -f $i | cut -d ',' -f $fila`
			#Hallamos las páginas que son la dirección de página entre el tamaño de página
			pagFichero[$p,$leepags]=$(( directions[$p,$leepags] / "$tamPag" ))
			((leepags++))
		done
		#referencia proceso(empiezan desde P01)
		local aux=0
		((aux=p+1))
		if [[ $aux -gt 9 ]];then 
			Ref[$p]="P$aux"
			else
			Ref[$p]="P0$aux"
		fi	
		((p++))
	done 
	p=$((numProcesos-1))
}

#des: Función que cuenta cuantas páginas/direcciones tiene cada proceso y almacena estos datos en un vector y
#		Calcula cuantas direcciones tiene el proceso con más direcciones de pagina -> $mayorNpags
cuentapaginas(){
	local contadorpalabras=0
	local ifila=$fila	 						#indica la fila de la que se va a contar las palabras
	local npags=0;							#Utilizada en la funcion vermaxpags, para recorrer numero de paginas de los procesos, y ver cual es el que más tiene
	maxPalabras=0;						#Utilizada en la funcion vermaxpags, guarda el Número máximo de páginas de los procesos

	contadorpalabras=`awk "NR==$ifila" $rutaFicheroDatos | wc -w`
	(( npags=contadorpalabras-2 ))
	npagsProcesos[$p]=$npags			#obtenemos cuantas direcciones/paginas hay en cada proceso

	if (( contadorpalabras >= maxPalabras ));then 
			maxPalabras=$contadorpalabras
	fi
}

####################################
##  ENTRADA DE DATOS Aleatoria  ##
####################################

# des: Busca en datosScript/rangos los ficheros disponibles y da al usuario a elegir.
# Establece el contenido nomFicheroRangos a lo que haya elegido el usuario
preguntaqueficheroleer_rangos(){
	local seleccion
	p=0

	for arch in "$CARPETA_RANGOS"/*.txt ;do
		lista+=("${arch##*/}")
	done
	# Si no hay archivos en la carpeta
	if [ "${lista[0]}" == "*" ];then
		echo -e "No se ha encontrado ningún archivo de texto en la carpeta $CARPETA_RANGOS. Saliendo..."
		exit
	fi
	
	echo ""
	echo -e "\e[1;38;5;81m¿De qué archivo quieres extraer los datos de los rangos?\e[0m"
	echo -e "\e[1;38;5;81mEstos son los archivos disponibles: \e[0m"
	# Por cada archivo en la carpeta imprime una linea
	for archivo in ${!lista[*]};do
		echo -e "	\e[1;32m$(($archivo + 1))\e[0m- ${lista[$archivo]}"
	done
	echo ""
	echo -n "Selecciona uno: "
	while :;do
        leer_numero_entre seleccion 1 ${#lista[*]}
        # En caso de que el valor devuelto por la función anterior
        case $? in
            # Valor válido
            0 )
                break
            ;;
            # Valor no número natural
            * )
                echo -n -e " Debes introducir un número entre 1 y ${#lista[*]}: "
            ;;
        esac
    done
	((seleccion--))
	#Asignar nombre del fichero que se usará
	nomFicheroRangos="${lista[$seleccion]}"

	# rutaFicheroRangos="./$CARPETA_RANGOS/$nomFicheroRangos"
	echo -e "\e[1;32mSe tomarán los datos del archivo $nomFicheroRangos\e[0m"
	sleep 1
	clear
	unset lista
}
# plan: validar formato de los datos en los archivos

#des: Función que lee los datos del fichero al cual se accede desde 'rutaFicheroRangos'
leerFicheroRangos(){
	tamPagmin=`head -n 1 $rutaFicheroRangos | tail -n 1 | cut -d "-" -f 1`
	tamPagmax=`head -n 1 $rutaFicheroRangos | tail -n 1 | cut -d "-" -f 2`
	marcosTotalesmin=`head -n 2 $rutaFicheroRangos | tail -n 1 | cut -d "-" -f 1`
	marcosTotalesmax=`head -n 2 $rutaFicheroRangos | tail -n 1 | cut -d "-" -f 2`
	numProcesosmin=`head -n 3 $rutaFicheroRangos | tail -n 1 | cut -d "-" -f 1`
	numProcesosmax=`head -n 3 $rutaFicheroRangos | tail -n 1 | cut -d "-" -f 2`
	tllmin=`head -n 4 $rutaFicheroRangos | tail -n 1 | cut -d "-" -f 1`
	tllmax=`head -n 4 $rutaFicheroRangos | tail -n 1 | cut -d "-" -f 2`
	nMarmin=`head -n 5 $rutaFicheroRangos | tail -n 1 | cut -d "-" -f 1`
	nMarmax=`head -n 5 $rutaFicheroRangos | tail -n 1 | cut -d "-" -f 2`
	npagsmin=`head -n 6 $rutaFicheroRangos | tail -n 1 | cut -d "-" -f 1`
	npagsmax=`head -n 6 $rutaFicheroRangos | tail -n 1 | cut -d "-" -f 2`
	direccionesmin=`head -n 7 $rutaFicheroRangos | tail -n 1 | cut -d "-" -f 1`
	direccionesmax=`head -n 7 $rutaFicheroRangos | tail -n 1 | cut -d "-" -f 2`
}

#Des: Funcion que se encarga de ecopilar los datos de los rangos y de generar los datos de los procesos de forma aleatoria. También guarda estos datos.
datos_random(){
	local tamPagmin=" "
	local tamPagmax=" "
	local marcosTotalesmin=" "
	local marcosTotalesmax=" "
	local numProcesosmin=" "
	local numProcesosmax=" "
	local tllmin=" "
	local tllmax=" "
	local nMarmin=" "
	local nMarmax=" "
	local npagsmin=" "
	local npagsmax=" "
	local direccionesmin=" "
	local direccionesmax=" "

	#Obtener los rangos
	case "${introdatos}" in
		4) #Introducir rangos de forma manual
			preguntadondeGuardarDatosManuales "rangos"
			rutaFicheroRangos="./$CARPETA_RANGOS/$nomFicheroRangos"

			#pedir datos
			pide_rangos_TamPag
			pide_rangos_MarcosTotales
			((tamMem=tamPag*marcosTotales))
			pide_rangos_numprocesos
			pide_rangos_llegada
			while :;do
				pide_rangos_marcos
				pide_rangos_npags
				if [[ $npagsmin < $nMarmin ]]; then
					clear
					imprime_rangos_resumen
					echo
					echo "El minimo número de páginas de los procesos es menor al mínimo número de marcos que ocupan los procesos."\
						"Puede producirse un desperdicio de memoria."
					echo -e "¿Quiere cambiar estos parámetros?"
					echo ""
					echo -e "\e[1;33m    s\e[0m- Sí, volver a introducir los rangos de número de marcos y de número de páginas "
					echo -e "\e[1;33m    n\e[0m- No, continuar"
					echo ""
					leer -p "Selecciona: " cambio
					until [[ $cambio = "s" || $cambio = "n" ]];do
						echo ""
						echo -en "Selecciona \e[1;31ms\e[0m o \e[1;31mn\e[0m: "
						leer -r cambio
					done
					if [[ $cambio = "n" ]];then
						break
					 	else						
						npagsmin=" "
						npagsmax=" "
						nMarmin=" "
						nMarmax=" "
					fi

				 else
					break
				fi
			done
			pide_rangos_direcciones

			{	#guardar datos de rangos
			echo "$tamPagmin-$tamPagmax"
			echo "$marcosTotalesmin-$marcosTotalesmax"
			echo "$numProcesosmin-$numProcesosmax"
			echo "$tllmin-$tllmax"
			echo "$nMarmin-$nMarmax"
			echo "$npagsmin-$npagsmax"
			echo "$direccionesmin-$direccionesmax" ; } > $rutaFicheroRangos
			echo -e "\e[1;32mSe han guardado los datos en \e[1;33m'$rutaFicheroRangos'\e[0m\e[0m"
			sleep 1

		;;		#plan: comprobar que los datos están todos y si no dar la opción de rellenar los que faltan o de elegir otro metodo de introducir datos. y si no cambiar el fichero.
		5)	#Fichero con los rangos de la última ejecución
			rutaFicheroRangos="./$CARPETA_RANGOS/$FICHERO_RANGOS_ESTANDAR"
			if [ -f "$rutaFicheroRangos" ]; then
				leerFicheroRangos
				aleatorio_entre marcosTotales $marcosTotalesmin $marcosTotalesmax
				aleatorio_entre tamPag $tamPagmin $tamPagmax
				aleatorio_entre numProcesos $numProcesosmin $numProcesosmax
				((tamMem=tamPag*marcosTotales))
			 else
				echo -e "\e[31mNo se ha encontrado el fichero '$FICHERO_RANGOS_ESTANDAR'\e[0m] "
				read -t 3
				datos
			fi
		;;
		6)	#Otro fichero de rangos
			preguntaqueficheroleer_rangos				#<-- de aquí salen CARPETA_RANGOS y nomFicheroRangos
			rutaFicheroRangos="./$CARPETA_RANGOS/$nomFicheroRangos"
			leerFicheroRangos
			aleatorio_entre marcosTotales $marcosTotalesmin $marcosTotalesmax
			aleatorio_entre tamPag $tamPagmin $tamPagmax
			aleatorio_entre numProcesos $numProcesosmin $numProcesosmax
			((tamMem=tamPag*marcosTotales))
		;;
	esac
	clear
	cabeceraMenus
	imprime_rangos_resumen
	echo
	echo -e "\e[1;32mSe crearán los procesos con los datos introducidos \e[0m"
	preguntadondeGuardarDatosManuales datos
	rutaFicheroDatos="./$CARPETA_DATOS/$nomFicheroDatos"

	sleep 1
	# clear
	
	local p=0
	local pags=0
	local cambio="n"
	#Crear los datos de cada proceso
	for (( p=0 ; p < numProcesos ; p++ )); do
		#referencia proceso(empiezan desde P01)
		local aux=0
		((aux=p+1))
		if [[ $aux -gt 9 ]];then 
			Ref[$p]="P$aux"					
			else
			Ref[$p]="P0$aux"
		fi
		#crear tiempos de llegada
		aleatorio_entre tiempoLlegada[$p] $tllmin $tllmax
		
		#crear tiempo de ejecución que servirá tb para saber cuantas direcciones de página hacer
		aleatorio_entre npagsProcesos[$p] $npagsmin $npagsmax
		
		#crear número de marcos de cada proceso
			#comprobar si el máximo de marcos es mayor que el total de marcos del sistema(importante para los datos metidos por ficher)
		if [[ $nMarmax -gt $marcosTotales ]];then
			aleatorio_entre nMarcos[$p] $nMarmin $marcosTotales
			else
			aleatorio_entre nMarcos[$p] $nMarmin $nMarmax
		fi		
		#crear direcciones de cada proceso con su pag correspondiente
		tiempoEjec[$p]=${npagsProcesos[$p]}
		for (( pags=0 ; pags < npagsProcesos[$p] ; pags++ )); do
			aleatorio_entre directions[$p,$pags] $direccionesmin $direccionesmax
			pagFichero[$p,$pags]=$(( directions[$p,$pags] / "$tamPag" ))
		done
	done
	echo
	echo -e "\e[1;32mSe han creado los procesos\e[0m"

	#guardar los datos en el fichero
	{
	echo "${tamMem}"
	echo "${tamPag}"
	for (( p=0 ; p < numProcesos ; p++ )); do
		echo -n "${tiempoLlegada[$p]} "
		echo -n "${nMarcos[$p]} "
		for (( pags=0 ; pags < npagsProcesos[$p] ; pags++ )); do
			echo -n "${directions[$p,$pags]} "
		done
		echo ""
	done
	} > "$rutaFicheroDatos"
	echo -e "\e[1;32mSe han guardado los datos en \e[1;33m'$rutaFicheroDatos'\e[0m"
	sleep 2
}

# DES: Crea un número pseudoaleatorio y lo asigna a la variable.
# USO: aleatorio_entre var min max
aleatorio_entre() {
    eval "${1}=$( shuf -i "${2}"-"${3}" -n 1 )"
}

# des: funcion que muestra un resumen de los datos de rangos obtenidos
imprime_rangos_resumen(){
		# echo -e " FCFS/SJF+Paginación+Seg.Op+M.Continua+Reubicable"
		echo -e "|Tamaño total de la memoria:		$tamMem"
		echo -e "|Tamaño de las páginas:			[ $tamPagmin - $tamPagmax ]	-> $tamPag"
		echo -e "|Número de marcos (memoria):		[ $marcosTotalesmin - $marcosTotalesmax ]	-> $marcosTotales"
		echo -e "|Número de procesos:				[ $numProcesosmin - $numProcesosmax ]	-> $numProcesos"
		echo -e "|Tiempo de llegada:				[ $tllmin - $tllmax ]"
		echo -e "|Número de marcos (procesos):		[ $nMarmin - $nMarmax ]"
		echo -e "|Número de páginas:				[ $npagsmin - $npagsmax ]"
		echo -e "|Números de direcciones:			[ $direccionesmin - $direccionesmax ]"
		#plan: mientras se piden datos hacer que se resalte el dato pedido.
}

pide_rangos_TamPag(){
	clear
	imprime_rangos_resumen
	echo ""
	echo -n "Tamaño de las páginas mínimo: "
	while :;do
        leer_numero tamPagmin
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
				printf "%s" "$tamPagmin" > "$rutaFicheroRangos"
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "Introduce un número natural: "
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "Valor demasiado grande: "
            ;;
        esac
    done
	clear
	imprime_rangos_resumen
	echo ""
	echo -n "Tamaño de las páginas máximo: "
	while :;do
        leer_numero_entre tamPagmax "$tamPagmin"
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
				printf "-" >> "$rutaFicheroRangos"
				printf "%s\n" "$tamPagmax" >> "$rutaFicheroRangos"
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "Introduce un número natural: "
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "Valor demasiado grande: "
            ;;
            # Valor demasiado pequeño
            4 )
                echo -n -e "El máximo debe ser mayor que el mínimo:"
            ;;
        esac
    done
	aleatorio_entre tamPag $tamPagmin $tamPagmax
}

pide_rangos_MarcosTotales(){
	clear
	imprime_rangos_resumen
	echo ""
	echo -n "Número mínimo de marcos totales de la memoria: "
	while :;do
        leer_numero marcosTotalesmin
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
				printf "%s" "$marcosTotalesmin" >> "$rutaFicheroRangos"
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "Introduce un número natural: "
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "Valor demasiado grande: "
            ;;
        esac
    done
	clear
	imprime_rangos_resumen
	echo ""
	echo -n "Número máximo de marcos totales de la memoria: "
	while :;do
        leer_numero_entre marcosTotalesmax $marcosTotalesmin
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
				printf "-" >> "$rutaFicheroRangos"
				printf "%s\n" "$marcosTotalesmax" >> "$rutaFicheroRangos"
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "Introduce un número natural: "
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "Valor demasiado grande: "
            ;;
            # Valor demasiado pequeño
            4 )
                echo -n -e "El máximo debe ser mayor que el mínimo:"
            ;;
        esac
    done
	aleatorio_entre marcosTotales $marcosTotalesmin $marcosTotalesmax
}

pide_rangos_numprocesos(){
	clear
	imprime_rangos_resumen
	echo ""
	echo -n "Mínimo de proesos a crear: "
	while :;do
        leer_numero_entre numProcesosmin 1 "$maximoProcesos"
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
				printf "%s" "$numProcesosmin" >> "$rutaFicheroRangos"
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "Introduce un número natural: "
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "El número máximo de procesos es ${maximoProcesos}: "
            ;;
            # Valor demasiado pequeño
            4 )
                echo -n -e "Se debe crear al menos 1 proceso:"
            ;;
        esac
    done
	clear
	imprime_rangos_resumen
	echo ""
	echo -n "Máximo de proesos a crear: "
	while :;do
        leer_numero_entre numProcesosmax "$numProcesosmin" "$maximoProcesos"
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
				printf "-" >> "$rutaFicheroRangos"
				printf "%s\n" "$numProcesosmax" >> "$rutaFicheroRangos"
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "Introduce un número natural: "
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "El número máximo de procesos es ${maximoProcesos}: "
            ;;
            # Valor demasiado pequeño
            4 )
                echo -n -e "El máximo del rango debe ser mayor que el mínimo:"
            ;;
        esac
    done
	aleatorio_entre numProcesos $numProcesosmin $numProcesosmax
}

pide_rangos_llegada(){
	clear
	imprime_rangos_resumen
	echo ""
	echo -n "Tiempo de llegada mínimo: "
	while :;do
        leer_numero tllmin
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
				printf "%s" "$tllmin" >> "$rutaFicheroRangos"
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "Introduce un número natural: "
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "Valor demasiado grande: "
            ;;
        esac
    done
	clear
	imprime_rangos_resumen
	echo ""
	echo -n "Tiempo de llegada máximo: "
	while :;do
        leer_numero_entre tllmax "$tllmin"
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
				printf "-" >> "$rutaFicheroRangos"
				printf "%s\n" "$tllmax" >> "$rutaFicheroRangos"
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "Introduce un número natural: "
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "Valor demasiado grande: "
            ;;
            # Valor demasiado pequeño
            4 )
                echo -n -e "El máximo debe ser mayor que el mínimo:"
            ;;
        esac
    done
}

pide_rangos_marcos(){
	clear
	imprime_rangos_resumen
	echo ""
	echo -n "Número de marcos mínimo de los procesos: "
	while :;do
        leer_numero_entre nMarmin 1 "$marcosTotales"
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
    			printf "%s" "$nMarmin" >> "$rutaFicheroRangos"
           		break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "Introduce un número natural: "
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "El número de marcos de los procesos no puede ser mayor que el número total de marcos: "
            ;;
			# Valor demasiado pequeño
            4 )
                echo -n -e "El número de marcos mínimo es 1: "
            ;;
        esac
    done
	clear
	imprime_rangos_resumen
	echo ""
	echo -n "Número de marcos máximo de los procesos: "
	while :;do
        leer_numero_entre nMarmax "$nMarmin" "$marcosTotales"
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
				printf "-" >> "$rutaFicheroRangos"
				printf "%s\n" "$nMarmax" >> "$rutaFicheroRangos"
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "Introduce un número natural: "
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "El número de marcos de los procesos no puede ser mayor que el número total de marcos: "
            ;;
            # Valor demasiado pequeño
            4 )
                echo -n -e "El máximo debe ser mayor que el mínimo:"
            ;;
        esac
    done
}

pide_rangos_npags(){
	clear
	imprime_rangos_resumen
	echo ""
	echo -n "Número mínimo de páginas de los procesos: "
	while :;do
        leer_numero npagsmin
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
				printf "%s" "$npagsmin" >> "$rutaFicheroRangos"
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "Introduce un número natural: "
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "Valor demasiado grande: "
            ;;
        esac
    done
	clear
	imprime_rangos_resumen
	echo ""
	echo -n "Número mínimo de páginas de los procesos: "
	while :;do
        leer_numero_entre npagsmax $npagsmin
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
				printf "-" >> "$rutaFicheroRangos"
				printf "%s\n" "$npagsmax" >> "$rutaFicheroRangos"
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "Introduce un número natural: "
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "Valor demasiado grande: "
            ;;
            # Valor demasiado pequeño
            4 )
                echo -n -e "El máximo debe ser mayor que el mínimo:"
            ;;
        esac
    done
}

pide_rangos_direcciones(){
	clear
	imprime_rangos_resumen
	echo ""
	echo -n "Número de dirección de página mínimo: "
	while :;do
        leer_numero direccionesmin
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
				printf "%s" "$direccionesmin" >> "$rutaFicheroRangos"
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "Introduce un número natural: "
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "Valor demasiado grande: "
            ;;
        esac
    done

	clear
	imprime_rangos_resumen
	echo ""
	echo -n "Número de dirección de página máximo: "
	while :;do
        leer_numero_entre direccionesmax $direccionesmax $direccionesmin
        # En caso de que el valor devuelto por la función anterior
        case $? in  
            # Valor válido
            0 )
				printf "-" >> "$rutaFicheroRangos"
				printf "%s\n" "$direccionesmax" >> "$rutaFicheroRangos"
                break
            ;;
            # Valor no número natural o No se introduce nada
            1 | 2)
                echo -n -e "Introduce un número natural: "
            ;;
            # Valor demasiado grande
            3 )
                echo -n -e "Valor demasiado grande: "
            ;;
            # Valor demasiado pequeño
            4 )
                echo -n -e "El máximo debe ser mayor que el mínimo:"
            ;;
        esac
    done
}

#Fin de funciones de recogida de datos
######################################

# ███████████████████████████████
# ███████████████████████████████
# █                             █
# █     EJECUCIÓN DEL ALGORTMO  █
# █                             █
# ███████████████████████████████
# ███████████████████████████████

# des: pregunta al usuario que modo de visualización de la ejecución quiere
pideModoEjecucion(){
	cabeceraMenus
	echo -e "\e[1;38;5;81mModo de visualización de la ejecución: \e[0m"
	echo ""
	echo -e "\e[1;33m	1\e[0m- Por eventos (Pulsar Enter en cada evento)"
	echo -e "\e[1;33m	2\e[0m- Automático (Esperar unos segundos entre cada evento)"
	echo -e "\e[1;33m	3\e[0m- Completo (Directo al resumen con datos de la ejecución y fallos de página)"
	echo ""
	leer -p "Seleccione una opción: " modoEjecucion
	until [[ $modoEjecucion = 1 || $modoEjecucion = 2 || $modoEjecucion = 3 ]]
	do
		echo -e "Escoje entre las opciones \e[1;31m1, 2\e[0m y \e[1;31m3\e[0m"
		leer -p "Selecciona una opción: " modoEjecucion
	done
	#si elige el modo Automatico
	if [[ $modoEjecucion = 2 ]];then
		#pedir el tiempo de espera
		leer -p "Indique el tiempo de espera entre eventos(segundos): " TesperaEjecAuto
		until [[ $TesperaEjecAuto -gt 0 ]]
		do
			echo -e "El tiempo de espera entre eventos debe ser \e[1;31mpositivo\e[0m"
			leer -p "Intentelo de nuevo: " TesperaEjecAuto
		done
		echo "tiempo de espera introducido: $TesperaEjecAuto"

		else
			TesperaEjecAuto=3
	fi
	clear
	sleep 1
}

#### Funciones de ejecución del algoritmo #####
###############################################

#descripción: funcion que gestiona los loops de la ejecución
ejecucion(){
 # Variables locales

    # ------------VARIABLES SOLO PARA LA EJECUCIÓN-------------
    # Memoria
    local memoriaProceso=()         # Contiene el proceso que hay en cada marco. El índice respectivo está vacío si no hay nada.
    local memoriaPagina=()          # Contiene la página que hay en cada marco. El índice respectivo está vacío si no hay nada.
    local memoriaLibre=$marcosTotales # Número de marcos libres. Se empieza con la memoria vacía.
    local memoriaOcupada=0          # Número de marcos ocupados. Empieza en 0.
    local memoriaBitR=()                   # Contiene el bit  página en memoria. El índice está vacío si no hay nada.

    # Procesos
    local pc=()                     # Contador de los procesos. Indica la siguiente instrucción a ejecutar para cada proceso.(inica la pagina a ejecutar)
    for p in "${ordenados[@]}";do pc[$p]=0 ;done # Poner contador a 0 para todos los procesos

    declare -A procesoMarcos        # Contiene los marcos asignados a cada proceso actualmente
	local marcoInicial=()
	local marcoFinal=()
    local estado=()                 # Estado de cada proceso	# [0=fuera del sistema 1=en espera para entrar a memoria 2=en espera para ser ejecutado 3=en ejecución 4=Finalizado]
    for p in "${ordenados[@]}";do estado[$p]="Fuera de sistema" ;done # Poner todos los procesos en estado 0 (fuera del sistema)

    local siguienteMarco=""         # Puntero al siguiente marco en el que se va a introducir una página si no está ya en memoria.
	local llegados=0;				# numero de procesos que han llegado hasta el momento

    # Tiempos de espera, de ejecución y restante de ejecución
    local tiempoEspera=()       # Tiempo de espera de cada proceso
    local tiempoRetorno=()       # Tiempo de retorno (Desde llegada hasta fin de ejecución) 
    local tiempoRestanteEj=()       # Tiempo restante de ejecución

    # Colas
    local colaLlegada=("${ordenados[@]}") # Procesos que están por llegar. En orden de llegada
    local colaMemoria=()            # Procesos que han llegado pero no caben en la memoria y están esperando
    local colaEjecucion=()          # Procesos en memoria esperando a ser ejecutados. Se ordena según el algorimo dado (FCFS o SJF)
    local enEjecucion               # Proceso en ejecución (Vacío si no se ejecuta nada)

    # Reubicación
    local memoriaProcesoPrevia=()   # Estado de la memoria previo a la reubicación
    local memoriaPaginaPrevia=()    # Estado de la memoria previo a la reubicación
    local memoriaBitrPrevia=()       # Estado de la memoria previo a la reubicación

    local memoriaProcesoReubicada=()    # Estado de la memoria justo después de reubicar
    local memoriaPaginaReubicada=()     # Estado de la memoria justo después de reubicar
    local memoriaBitrReubicada=()

    # ------------VARIABLES PARA EL MOSTRADO DE LA INFORMACIÓN-------------
    local mostrarPantalla=1         # [1=Se va a mostrar la pantalla 0=No se muestra porque no ha ocurrido nada interesante]

    local reubicacion=0             # [0=no ha habido reubicación 1=ha habido reubicación]

    # Anchos para la tabla de procesos
    local anchoColTEsp=5
    local anchoColTRet=5
    local anchoColTREj=$(( $anchoColTej + 1 ))
    local anchoEstados=16

    # Datos de los eventos que han ocurrido
    local llegada=()                # Procesos que han llegado en este tiempo
    local entrada=()                # Procesos que han entrado a memoria en este tiempo
    local iniciado=""                 # Proceso que ha empezado a ejecutarse
    local finalizado=""                    # Proceso que ha finalizado su ejecución

    declare -A resumenPaginas        # Contiene información de los fallos de página que han habido durante la ejecución del proceso
                                    # se muestra cuando un proceso finaliza su ejecución. resumenPaginas[$momento,$marco]
    declare -A resumenfallos
	declare -A resumenBit
	declare -A resumenPuntero
    declare -A paginaTiempo         # Contiene el tiempo en el que se introduce cada página del proceso [$proc,$pc]
    local marcoFallo=()             # Marco que se usa para cada página
    local numFallos=()              # Número de fallos de cada proceso
    for p in ${ordenados[*]};do numFallos[$p]=0 ;done
	declare -A paginaFallo
	declare -A maxcols
	declare -A colsP
	local colsM
    # Variables para la linea temporal
    local tiempoProceso=()          # Contien el proceso que está en ejecución en cada tiempo
    local tiempoPagina=()           # Contiene la página que se ha ejecutado en cada tiempo

    local numProcesosFinalizados=0

    # VARIABLES PARA LA PANTALLA DE RESUMEN
    local procesotInicio=()          # Contiene el tiempo de inicio de cada proceso
    local procesotFin=()             # COntiene el tiempo de fin de cada proceso

# Ejecución

    # Cada ciclo se incrementa el tiempo t
    for (( t=0; ; t++ ));do

        # Si el tiempo es más grande que el ancho general
        if [ ${#t} -gt $anchura ];then
            anchura=${#t}
        fi

        # Llegada de procesos, ejecución, introducción a memoria...

		# Calcular tiempo de espera y de ejecución para los procesos
		ejecutar_tesp_tret

		# Si hay un proceso en ejecución significa que en el instante anterior se
		# ha introducido una página suya y durante el tiempo que ha pasado se ha ejecutado
		# por lo que hay que decrementar su tREj
		if [[ -n "$enEjecucion" ]];then

			# Decrementar tiempo restante de ejecución
			((tiempoRestanteEj[$enEjecucion]--))
			
			# Guardar el estado de la memoria en este momento para luego mostrar el resumen con los fallos
			ejecutar_guardar_fallos

			# Si el proceso se ha terminado de ejecutar
			if [ ${tiempoRestanteEj[$enEjecucion]} -eq 0 ];then
				ejecuta_fin_ejecutar
			fi
		fi

		ejecuta_llegada
		ejecuta_entradaMemoria
		# Si han entrado procesos ordenar la cola de ejecución ( $? es el valor devuelto por la función anterior)
		if [ $? -eq 0 ];then
			# Ordenar la cola de ejecución según FCFS o SJF
			reordenacion_colaEjecucion
		fi

		# Si no hay procesos en ejecución y hay procesos esperando a ser ejecutados
		if [[ -z "$enEjecucion" ]] && [[ ${#colaEjecucion[@]} -gt 0 ]]; then
			ejecutar_entradaCPU
		fi
		# Si hay un proceso en ejecución, introducir su siguiente página a memoria
		if [[ -n "$enEjecucion" ]];then
			ejecutar_relojSO

			# Incrementar el contador del proceso
			(( pc[$enEjecucion]++ ))
		fi

	####################################################################
	# Volcado en pantalla con los eventos que ocurren
        if [[ $mostrarPantalla -eq 1 ]];then
			
			case "${modoEjecucion}" in
			1)	#Ejecución por eventos (pulsa enter para ver el siguiente evento)
				clear
				diagramaresumen
				printf "\n Pulsa \e[1;33mINTRO\e[0m para continuar "
				leer -r
				echo
			;;
			2)	#Ejecución automática (espera un determinado numero de segundos entre cada evento)
				clear
				diagramaresumen
				sleep "$TesperaEjecAuto"
			;;
			3) #Ejecución completa (no espera nada entre pantallas)
				diagramaresumen >> "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE"
				diagramaresumen >> "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"
				clear
				echo -n 'Ejecutando...' >&3
				local cargando
				((cargando=100*numProcesosFinalizados/numProcesos))
				printf "(%d%%)" "$cargando" >&3
			;;
			esac

			# CONTROLdeERRORES aqui
			limpiar_eventos
		fi
		
		# Si no hay ningún proceso en ninguna cola ni ejecutandose, salir del loop.
		if [[ ${#colaLlegada[*]} -eq 0 ]] && [[ ${#colaMemoria[*]} -eq 0 ]] && [[ ${#colaEjecucion[*]} -eq 0 ]] && [[ -z "$enEjecucion" ]] ;then
            break
        fi
    done
    # clear
    # Mostrar el resumen de la ejecución
	echo
	imprime_resumenfinal
	echo ""
	echo ""
	echo -e "\e[1;31mFin de la ejecución.\e[0m"
	echo
	echo -n -e "Pulsa \e[1;33mINTRO\e[0m para continuar. "
	leer -r
	echo
}

# DES: Calcular tiempo de espera y de ejecución para los procesos
ejecutar_tesp_tret(){
	# Por cada proceso que está esperando a entrar a memoria o a ser ejecutado
    for p in ${colaMemoria[*]} ${colaEjecucion[*]};do

        # Incrementar su tiempo de espera y de retorno
        ((tiempoEspera[$p]++))
        ((tiempoRetorno[$p]++))

        # Calcular anchos para la tabla
        [ ${#tiempoEspera[$p]} -gt $(( ${anchoColTEsp} - 2 )) ] \
            && anchoColTEsp=$(( ${#tiempoEspera[$p]} + 2 ))
        [ ${#tiempoRetorno[$p]} -gt $(( ${anchoColTRet} - 2 )) ] \
            && anchoColTRet=$(( ${#tiempoRetorno[$p]} + 2 ))
    done

    # Si hay un proceso en ejecución
    if [[ -n "$enEjecucion" ]];then
        # Incrementar su tiempo de retorno
		((tiempoRetorno[$enEjecucion]++))

        # Calcular anchos para la tabla
        [ ${#tiempoRetorno[$enEjecucion]} -gt $(( ${anchoColTRet} - 2 )) ] \
            && anchoColTRet=$(( ${#tiempoRetorno[$enEjecucion]} + 2 ))
    fi
}

# DES: Atender la llegada de procesos
ejecuta_llegada(){
	# Por cada proceso en la cola de llegada
    for p in "${colaLlegada[@]}";do
        # Si su tiempo de llegada es igual al tiempo actual
        if [ ${tiempoLlegada[$p]} -eq $t ];then
            # Quitar proceso de la lista de llegada
            colaLlegada=("${colaLlegada[@]:1}")

            # Añadir proceso a la cola para entrar a memoria
            colaMemoria+=($p)

            # Cambiar el estado del proceso(a en espera)
            estado[$p]="En espera"

			#Inicializar tiempo de espera y retorno
			tiempoEspera[$p]=0
			tiempoRetorno[$p]=0

			#Incrementar contador de cuantos procesos han llegado
			((llegados++))

            # Añadir proceso a los que han llegada para mostrarlo
            llegada+=($p)
            # Mostrar pantalla porque es un evento importante
            mostrarPantalla=1
        else
            # Como están en orde de llegada, en cuanto nos topemos con un proceso
            # que aún no llega sabemos que no va a llegar ningún otro
            break
        fi
    done
} 

# DES: Introducir procesos que han llegado a memoria si se puede
# RET: 0 -> han entrado procesos a memoria; 1 -> no han entrado procesos
ejecuta_entradaMemoria(){
	# Contador de cuantos procesos han entrado
	local cont=0
	local espacio;
	# Por cada proceso en la cola de memoria
    for p in "${colaMemoria[@]}";do

		#si no hay suficiente espacio libre para que entre el proceso a memoria
		if [[ ${nMarcos[$p]} -gt $memoriaLibre ]];then
			# Como la entrada a memoria es FIFO si un proceso no puede entrar, los siguientes
            # tampoco porque la lista está ordenasa según tiempo de llegada
			break 				#sale del bucle
		fi
		while :; do
			espacio=0		# contador de los espacios libres seguidos que hay en la memoria.
			#recorrer marcos en busca de un espacio donde quepa el proceso completo.
			for (( marco=0 ; marco<marcosTotales ; marco++)); do 

				#si el marco está ocupado
				if [[ -n ${memoriaProceso[$marco]} ]];then
						#comienza de 0 la busqueda de un espacio suficientemente grande
						espacio=0

					#si el marco está libre
					else
					
						#Incrementar contador de espacios libres
						((espacio++))
						#si hay tanto espacio como marcos ocupa el proceso
						if [[ $espacio -eq ${nMarcos[$p]} ]];then

							# Quitar proceso del la cola de memoria
							colaMemoria=("${colaMemoria[@]:1}")

							#determinar qué marcos va a ocupar
							marcoFinal[$p]=$marco
							marcoInicial[$p]=$(( ${marcoFinal[$p]} - ${nMarcos[$p]} + 1 ))
							
							# Añadir proceso a la memoria, desde el marco inicial al marco final, incluido este último.
							for ((i=0, marc=${marcoInicial[$p]} ; marc<=${marcoFinal[$p]};marc++)); do
								
								memoriaProceso[$marc]="$p"
								procesoMarcos[$p,$i]=$marc
								#plan: mirar si poner lo de meter paginas tb(linea 2397 de script.sh)
								((i++))
								# Actualizar memoria libre y ocupada.
								((memoriaLibre--))
								((memoriaOcupada++))
							done

							# Añadir proceso a la cola de ejecución
							colaEjecucion+=("$p")

							# Cambiar el estado del proceso(a en memoria)
							estado[$p]="En memoria"

							# Establecer el tiempo restante de ejecución del proceso a su tiempo de ejecución total
							tiempoRestanteEj[$p]=${tiempoEjec[$p]}

							# Añadir proceso a la lista de procesos que han entrado a memoria para la pantalla
							entrada+=("$p")

							# Mostrar la pantalla porque es un evento importante
							mostrarPantalla=1

							# Incrementar contador
							((cont++))
							#como ya hay un sitio en el que el proceso ha entrado no hace falta recorrer más marcos ni reubicar.
							break 2
						fi
				fi
			done
			#si llega aquí significa que no ha encontrado un hueco suficientemente grande.
			#entonces hacer reubicación para intentarlo de nuevo.
			if [[ $reubicacion -eq 1 ]];then
				echo "Reubicación fallida"
				final_interrupcion
			 else
				ejecuta_reubicacion
			fi
		done
	done
	# Si no han entrado procesos devolver 1
    if [ $cont -eq 0 ];then
        return 1
    # Si han llegado devolver 0
    else
        return 0
    fi
}

# Des: reubica los procesos en memoria
ejecuta_reubicacion(){
    # Mostrar la pantalla porque la reubicación es un evento importante
	mostrarPantalla=1
    reubicacion=1

	#guardar el estado anterior de la memoria
	for (( marc=0 ; marc<marcosTotales; marc++ )); do
		memoriaProcesoPrevia[$marc]=${memoriaProceso[$marc]}
		memoriaPaginaPrevia[$marc]=${memoriaPagina[$marc]}
		memoriaBitrPrevia[$marc]=${memoriaBitR[$marc]}
	done
	for ((proc=0;proc<numProcesos;proc++));do
		marcoInicialPrev[$proc]=${marcoInicial[$proc]}
	done

	#recorrer los marcos
	for (( marco=0 ; marco <marcosTotales; marco++ )); do
		#por cada marco, desde el marco por el que vamos al marco vacío que más alante(hacia la izq) esté...
		for (( posicion=marco ; posicion > 0; posicion-- )); do
			# si el marco de delante está vacío
			if [[ -z ${memoriaProceso[$((posicion-1))]} ]];then 
				
				#asignar al marco anterior los datos del marco actual
				memoriaProceso[$(($posicion-1))]=${memoriaProceso[$posicion]}
				memoriaPagina[$(($posicion-1))]=${memoriaPagina[$posicion]}
				memoriaBitR[$(($posicion-1))]=${memoriaBitR[$posicion]}
				
				#si el marco actual está ocupado por un proceso y es el marco inicial de dicho proceso
				if [[ -n ${memoriaProceso[$posicion]} ]] && [[ ${marcoInicial[${memoriaProceso[$posicion]}]} -eq "$posicion" ]];then

					((marcoInicial[${memoriaProceso[$posicion]}]--))
					((marcoFinal[${memoriaProceso[$posicion]}]--))
					
					#actualizar los marcos asignados al proceso
					for (( i=0;i<nMarcos[${memoriaProceso[$posicion]}];i++));do
					((procesoMarcos[${memoriaProceso[$posicion]},$i]--))
					done
				fi
				#si el marco actual es el marcosiguiente de los fallos de página, moverlo
				if [[ -n ${memoriaProceso[$posicion]} ]] && [[ $siguienteMarco -eq "$posicion" ]];then
					((siguienteMarco--))
				fi
				#vaciar el marco actual
				unset "memoriaProceso[$posicion]"
				unset "memoriaPagina[$posicion]"
				unset "memoriaBitR[$posicion]"
			 else
			 	#no mover más y pasar al siguiente marco
			 	break
			fi
		done
	done

	for (( marc=0 ; marc<marcosTotales; marc++ )); do
		#guardar la nueva ubicación de los procesos
		memoriaProcesoReubicada[$marc]=${memoriaProceso[$marc]}
		memoriaPaginaReubicada[$marc]=${memoriaPagina[$marc]}
		memoriaBitrReubicada[$marc]=${memoriaBitR[$marc]}
	done
}

# DES: Ordenar cola de ejecución segun SJF
reordenacion_colaEjecucion(){
	local count=0 		#numero de procesos que hay que ordenar
	count="${#colaEjecucion[@]}"
	#si el algoritmo es sjf Hay que reordenar, si es FCFS ya está ordenado.
	#asignamos los valores a reordenados.(se usa en algunas funciones para pantalla)
	for (( pep=0; pep<=$count; pep++ ));do
		reordenados[$pep]=${colaEjecucion[$pep]}
	done
	if [[ $algoritmoOrdenacion = "SJF" ]]; then
		for (( kek=1; kek<=$count; kek++ ));do
			for (( jej=0; jej < ($count-$kek); jej++ ))
			do
				if [[ ${tiempoEjec[${reordenados[$jej]}]} -gt ${tiempoEjec[${reordenados[$jej+1]}]} ]];then
					aux=${reordenados[$jej]}
					reordenados[$jej]=${reordenados[$jej+1]}
					reordenados[$jej+1]=$aux
				fi
			done
		done
	fi
	#asignamos los valores a reordenados.(se usa en algunas funciones para pantalla)
	for (( pep=0; pep<$count; pep++ ));do
		colaEjecucion[$pep]=${reordenados[$pep]}
	done
}

# DES: Meter proceso al procesador
ejecutar_entradaCPU(){
	if [ ${#colaEjecucion[@]} -eq 0 ];then
		return
    fi
	# Asignar procesador al proceso
	enEjecucion="${colaEjecucion[0]}"

	# Quitar proceso de la cola de ejecución
	colaEjecucion=("${colaEjecucion[@]:1}")

	# Cambiar estado del proceso
	estado[$enEjecucion]="En ejecución"

	# Establece el marco siguiente al primer marco del proceso en ejecucución
	siguienteMarco=${procesoMarcos[$enEjecucion,0]}

	
	# Poner el proceso que se ha inciado para mostrarlo en la pantalla
	iniciado="$enEjecucion"

	# Mostrar la pantalla porque es un evento importante
	mostrarPantalla=1

	#El tiempo de inicio del proceso es el tiempo actual.
	procesotInicio[$enEjecucion]=$t
}

# DES: Introducir siguiente página del proceso a memoria, de acuerdo al algoritmo de reemplazo de páginas Segunda Oportunidad(Reloj)
# RET: 0=No ha habido fallo 1=Ha habido fallo
ejecutar_relojSO(){
	# Página que hay que introducir
    local pagina=${pc[$enEjecucion]} #aquí pc hace de contador de por qué pagina va
    pagina=${pagFichero[$enEjecucion,$pagina]}

	# Añadir proceso y página a la linea de tiempo
    tiempoProceso[$t]=$enEjecucion
    tiempoPagina[$t]=$pagina
    paginaTiempo[$enEjecucion,${pc[$enEjecucion]}]=$t

	# Comprobar en cada marco si la página ya está metida
	for (( i=0; i<${nMarcos[$enEjecucion]}; i++ )) do
		marco=${procesoMarcos[$enEjecucion,$i]}
		# Si se encuentra la página 
		if [[ -n ${memoriaPagina[$marco]} ]] && [[ ${memoriaPagina[$marco]} -eq "$pagina" ]];then
			#se vuelve a utilizar por lo tanto se cambia el bit de referencia a 1
			memoriaBitR[$marco]=1

			if [[ $siguienteMarco -eq $marco ]];then
				actualizarPuntero
			fi

			#no ha habido fallo de página
			return 0
		fi
	done

	#si despues de recorrer todo no se ha encontrado la pagina
	#Sustituir la pagina del marco que toque(siguientemarco)
	memoriaPagina[$siguienteMarco]=$pagina

	#poner el bit a 0
	memoriaBitR[$siguienteMarco]=0

	#apuntar el fallo en la página en la que ha sucedido.
	paginaFallo[$enEjecucion,${pc[$enEjecucion]}]="F"

	#Incrementar el contador de fallos del proceso
	(( numFallos[$enEjecucion]++ ))

	actualizarPuntero
}

# des: busca que marco es el siguiente que habría que reemplazar si se produce un fallo de página.
actualizarPuntero(){
	#Avanza la aguja del reloj, al siguiente marco de la lista que es el que lleva más tiempo sin cambiar de página
	((siguienteMarco++))
	((contador++))

	#Hacer que se recorran los marcos de forma circular, como un reloj ;)
	if [[ $siguienteMarco -gt ${marcoFinal[$enEjecucion]} ]]; then 
		siguienteMarco=${marcoInicial[$enEjecucion]}
	fi

	#buscar el siguiente marco, #mientras el marco esté ocupado por una página y el bit de signo sea 1...
	while [[ -n ${memoriaPagina[$siguienteMarco]} ]] && [[ ${memoriaBitR[$siguienteMarco]} -eq 1 ]] ;do

		#cambiar el bit de signo
		memoriaBitR[$siguienteMarco]=0

		#Avanza la aguja del reloj, al siguiente marco de la lista que es el que lleva más tiempo sin cambiar de página
		((siguienteMarco++))

		#Hacer que se recorran los marcos de forma circular, como un reloj ;)
		if [[ $siguienteMarco -gt ${marcoFinal[$enEjecucion]} ]]; then 
			siguienteMarco=${marcoInicial[$enEjecucion]}
		fi
	done
}

# DES: Guardar el estado de la memoria en este momento para luego mostrar el resumen con los fallos
#      No está directamente relacionado con la ejecución. Es solo para la pantalla.
ejecutar_guardar_fallos() {
    local pagina=$(( ${pc[$enEjecucion]} - 1 ))

	#guardar donde apunta el reloj
	resumenPuntero[$pagina]=$siguienteMarco

	colsP[$enEjecucion,$pagina]=1
	for (( i=0, mar=${marcoInicial[$enEjecucion]} ; mar<=${marcoFinal[$enEjecucion]}; mar++, i++)); do
		procesoMarcos[$enEjecucion,$i]=$mar
		resumenPaginas["$pagina,$mar"]="${memoriaPagina[$mar]}"
		resumenBit["$pagina,$mar"]="${memoriaBitR[$mar]}"

	 #Cálculos de ancho para la impresión por pantalla
		#contar cuanto ocupan máximo las páginas
		[[ ${#resumenPaginas[$pagina,$mar]} -gt ${colsP[$enEjecucion,$pagina]} ]] && colsP[$enEjecucion,$pagina]="${#resumenPaginas[$pagina,$mar]}"
		
		#contar cuanto ocupa el contenido que va a tener la celda correspondiente
		((suma=2+${colsP[$enEjecucion,$pagina]}))
		
		#Unicializar el vector para saber que ancho poner en la tabla de fallos.
		#si el ancho de los datos o del nombre del marco es mayor al numero que hay, se cambia el valor.
		[[ $suma -ge ${maxcols[$enEjecucion,$pagina]} ]] || [[ $((1+${#mar})) -gt ${maxcols[$enEjecucion,$pagina]} ]] && maxcols[$enEjecucion,$pagina]="$suma"
	done
}

# DES: Finalizar la ejecución del proceso
ejecuta_fin_ejecutar() {

    # Sacar el proceso de la memoria
	for (( mar="${marcoInicial[$enEjecucion]}"; mar<=${marcoFinal[$enEjecucion]}; mar++ ));do

        unset "memoriaProceso[$mar]"
        unset "memoriaPagina[$mar]"
        unset "memoriaBitR[$mar]"

        # Actualizar memoria libre y ocupada
        ((memoriaLibre++))
        ((memoriaOcupada--))

    done
	
	# Poner los marcos limite del proceso a - para que no muestre 0
	unset "marcoInicial[$enEjecucion]"
	unset "marcoFinal[$enEjecucion]"
	
	# 
	unset siguienteMarco

    # Poner el tiempor restanter de ejecución a - para que no muestre 0
    unset "tiempoRestanteEj[$enEjecucion]"

    # Actualizar le estado del proceso
    estado[$enEjecucion]="Finalizado"

    procesotFin[$enEjecucion]=$t

    # Poner el proceso que ha terminado para mostrarlo en pantalla
    finalizado=$enEjecucion
    # Mostrar la pantalla porque es un evento interesante
    mostrarPantalla=1

    # Liberar procesador
    unset "enEjecucion"

    ((numProcesosFinalizados++))

    siguienteMarco=""
}

####Funciones de volcado en pantalla###########
###############################################

# DES: Funcion que gestiona las funciones de volcado en pantalla
diagramaresumen(){
	printf "\n \n" | tee -a "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE" >> "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"
	#cabecera
	echo  " FCFS/SJF+Paginación+Seg.Op+M. Continua y Reubicable"
	#info sistema
	echo -e " T=$t   Algoritmo usado: $algoritmoOrdenacion   Memoria del Sistema: $tamMem   Tamaño de página: $tamPag   Marcos totales de la memoria: $marcosTotales"
	#eventos
	imprime_info_eventos
	#tabla procesos
	imprimeProcesos_ejecucion

	#tiempos medios de espera y retorno
		media 'tiempoEspera[@]'
		mediaespera="$lamedia"
		media 'tiempoRetorno[@]'
		mediadura="$lamedia"
		lamedia=0;
		printf " T. MEDIO ESPERA: %-6s  T. MEDIO RETORNO: %-6s \n" "${mediaespera}" "${mediadura}"

	calculaEspacios

	#Fallos de página si los hay
		if [[ -n "${finalizado}" ]];then
		imprime_fallos
		fi
	#Cola de ejecucion
		imprime_cola
	#reubicación
		if [ $reubicacion -eq 1 ];then
		imprime_reubicacion
		fi
	#marcos de página
	imprime_marcos

	#diagrama memoria
	imprime_barra_memoria

	#diagrama tiempo
	imprime_barra_tiempo
}

#DES: función que describe los eventos importantes que han sucedido en ese momento
imprime_info_eventos(){
	#eventos que llegan
		case ${#llegada[*]} in
			0 ) # Si no ha llegado ningún proceso no hacer nada
			;;        
			1 ) # Si ha llegada un proceso
				local temp=${llegada[0]}
				echo -e " Llega el proceso\e[1;3${colorjastag[$temp]}m ${Ref[$temp]}\e[0m"
			;;       
			* ) # Si ha llegado más de un proceso
				echo -e -n " Han llegado los procesos"
				for p in ${!llegada[*]};do
					# Número del proceso
					local temp=${llegada[$p]}

					# Si es el antepenúltimo proceso
					if [ $p -eq $(( ${#llegada[*]} - 2 )) ];then

						echo -e -n "\e[1;3${colorjastag[$temp]}m ${Ref[$temp]}\e[0m"

					# Si es el último proceso
					elif [[ $p -eq $(( ${#llegada[*]} - 1 )) ]];then

						echo -e " y\e[1;3${colorjastag[$temp]}m ${Ref[$temp]}\e[0m."

					# Si es cualquier otro proceso
					else

						echo -e -n "\e[1;3${colorjastag[$temp]}m ${Ref[$temp]}\e[0m,"

					fi
				done
			;;
		esac
	#eventos que entran a memoria
		# Por cada proceso que ha entrado a memoria
		for p in "${entrada[@]}";do
			echo -e " Entra a memoria el proceso\e[1;3${colorjastag[$p]}m ${Ref[$p]}\e[0m "
		done
	#eventos que entan al procesador
		if [[ -n "$iniciado" ]];then
			echo -e " Entra al procesador el proceso\e[1;3${colorjastag[$iniciado]}m ${Ref[$iniciado]}\e[0m"
		fi
	#proceso que se siguen ejecutando cuando eventos
		if [[ -n "$enEjecucion" ]] && [[ -z "$iniciado" ]];then
			echo -e " Se sigue ejecutando el proceso \e[1;3${colorjastag[$enEjecucion]}m ${Ref[$enEjecucion]}\e[0m"
		fi
	#eventos proceso finalizado
		if [[ -n "${finalizado}" ]];then
			echo -e " El proceso\e[1;3${colorjastag[$finalizado]}m ${Ref[$finalizado]}\e[0m ha \e[1;31mfinalizado\e[0m su ejecución" # y ha transcurrido este tiempo: $tiempoRetorno[]"
			echo -e " \033[3${colorjastag[$finalizado]}m ${Ref[$finalizado]}\033[0m    Tiempo de entrada: ${procesotInicio[$finalizado]} Tiempo Salida: ${procesotFin[$finalizado]} Tiempo Retorno: ${tiempoRetorno[$finalizado]}"
		fi
}

#des: funcion que imprime en pantalla la "tabla" con la info de los procesos.
#Ref Tll Tej nMar Tesp Tret Trej Mini Mfin Estado           Dirección-Página
imprimeProcesos_ejecucion(){
	declare -gA cols=( [Ref]=3 [Tll]=3 [Tej]=3 [nMar]=4 [Tesp]=4 [Tret]=4 [Trej]=4 [Mini]=4 [Mfin]=4 [Estado]=-16 [D-P]=1)
	local ord=0;					#se refiere al porceso que toca en orden
	local impaginillas=0 			#direcciones de pagina
	local contador=60;
	# echo "anchura=$anchura"
	# echo " Ref Tll Tej nMar Tesp Tret Trej Mini Mfin Estado           Dirección-Página"
	printf " %-*s %*s %*s %*s %*s %*s %*s %*s %*s %*s Dirección-Página " ${cols[Ref]} "Ref" ${cols[Tll]} "Tll" ${cols[Tej]} "Tej"  ${cols[nMar]} "nMar" ${cols[Tesp]} "Tesp" ${cols[Tret]} "Tret" ${cols[Trej]} "Trej" ${cols[Mini]} "Mini" ${cols[Mfin]} "Mfin" ${cols[Estado]} "Estado"

	impaginillas=1
	for ord in "${ordenados[@]}";do 		#en %*s, * es la cantidad de espacios que ocupará la variable que sustituye a los caracteres s(pone s pq cuando no hay nada es - y si pone d no no lo admite)				
		
		#Color
		echo -ne "\e[1;3${colorjastag[$ord]}m"
		#primeras 4 columnas
		printf "\n %-*s %*d %*d %*d " "${cols[Ref]}" ${Ref[$ord]} "${cols[Tll]}" ${tiempoLlegada[$ord]} "${cols[Tej]}" ${tiempoEjec[$ord]} "${cols[nMar]}" ${nMarcos[$ord]}
		#Color
		echo -ne "\e[0m\e[0;3${colorjastag[$ord]}m"
		#si están sin determinar poner un guión -
		[[ -n "${tiempoEspera[$ord]}" ]] \
            && printf "%${cols[Tesp]}s " "${tiempoEspera[$ord]}" \
            || printf "%${cols[Tesp]}s " "- "
        [[ -n "${tiempoRetorno[$ord]}" ]] \
            && printf "%${cols[Tret]}s " "${tiempoRetorno[$ord]}" \
            || printf "%${cols[Tret]}s " "- "
        [[ -n "${tiempoRestanteEj[$ord]}" ]] \
            && printf "%${cols[Trej]}s " "${tiempoRestanteEj[$ord]}" \
            || printf "%${cols[Trej]}s " "- "
		[[ -n "${marcoInicial[$ord]}" ]] \
            && printf "%${cols[Mini]}s " "${marcoInicial[$ord]}" \
            || printf "%${cols[Mini]}s " "- "
		[[ -n "${marcoFinal[$ord]}" ]] \
            && printf "%${cols[Mfin]}s " "${marcoFinal[$ord]}" \
            || printf "%${cols[Mfin]}s " "- "
		#Color
		echo -ne "\e[0m\e[1;3${colorjastag[$ord]}m"
		#estado
		printf "%*s " "${cols[Estado]}" "${estado[$ord]}"
		#debido a la tilde hay que añadir un espacio de más
		[[ ${estado[$ord]} == "En ejecución" ]] && echo -n " "
		contador=60
		#Color
		echo -ne "\e[0m"
		#Direcciones de página
		for (( impaginillas=0; impaginillas < npagsProcesos[ord] ; impaginillas++ ));	# a la variable donde estamos almacenando la cadena de texto le añadimos una a una las direcciones del proceso
		do
			#Contar cuantas columnas ocupa la siguiente direccion y página
			cols[D-P]="$( echo "${directions[$ord,$impaginillas]}-${pagFichero[$ord,$impaginillas]}" | wc -m )"
			if [[ $contador -gt $(($anchura-${cols[D-P]})) ]]; then
				printf "\n " #salto de linea
				contador=1	#reajustar el contador
			fi
			#subrayar si 
			if [[ impaginillas -lt ${pc[$ord]} ]];then
				#subrayar
				echo -ne "\e[4m\e[3${colorjastag[$ord]}m${directions[$ord,$impaginillas]}\e[0m"
				echo -ne "\e[4m\e[1;3${colorjastag[$ord]}m-${pagFichero[$ord,$impaginillas]}\e[0m " 
			else #normal
				echo -ne "\e[0;3${colorjastag[$ord]}m${directions[$ord,$impaginillas]}\e[0m" #la direccion va sin negrilla
				echo -ne "\e[1;3${colorjastag[$ord]}m-${pagFichero[$ord,$impaginillas]}\e[0m " #la página va en negrilla
			fi
			#incrementar el contador
			((contador=contador+${cols[D-P]}+1))
		done
		#desactivar colores
		echo -ne "\e[0m" 
	done
	echo ""
}

#Des: Funcion que calcula la media
# parametros: vector
media(){
	local vector=("${!1}")
	local sum
	local lamediasin=0;
	lamedia=0
	if [[ $llegados -ne 0 ]];then
		for x in "${vector[@]}";do
			((sum=sum+x))
		done
		lamedia=$( echo "scale=3; $sum/$llegados" | bc -l )
		#si el decima es 0,... no sale el 0 por lo tanto hay que añadirlo para que quede bien.
		lamediasin=$( echo "scale=0; $sum/$llegados" | bc -l )
		#si la media ya es cero no hace falta añadir nada, tampoco si el numero es mayor que 1
		[[ $lamediasin -lt 1 ]] && [[ $lamedia != "0" ]] && lamedia="0$lamedia"
	fi
}

#Des: funcion que imprime un resumen de los fallos de página ocurridos durante la ejecución del proceso fnalizado
# funcionamiento:mensaje del número de fallos
#				 tabla con el contenido de cada marco en el momento en el que ha entrado cada página del proceso
#				 - se muestran en un tono más claro los marcos donde enrta la página
#				 - se muestra subrayado el espacio donde se meterá la siguiente página
imprime_fallos(){
	#mensajito de cuantos fallos
	echo -ne " Se han producido ${numFallos[$finalizado]} fallos de página en la ejecución del proceso\e[1;3${colorjastag[$finalizado]}m ${Ref[$finalizado]}\e[0m"
	
	declare -A resumenfallos;						# vector donde se almacenan y forman las lineas que se imprimirán al final de la función
	local lel="";									# indicador de la linea
	num=$((${nMarcos[$finalizado]}-1));
	local colsM=${#procesoMarcos[$finalizado,$num]};	#ancho de lo que ocupa máximo el numero de marcos
	local estilo="\e[1;3${colorjastag[$finalizado]}m";
	local aux=0;									#numero de saltos de linea que vamos a tener que hacer.
	local columnas=$((3+colsM));					#contador de caracteres, inicializa contando dos espacios, la M y las columnas del numero del marco
	
	resumenfallos[$aux,0]=$( printf " %*s " "$colsM" "" )

	#imprimir paginas una a una (cabecera de la tabla)
	for ((pag=0;pag<${npagsProcesos[$finalizado]};pag++))
	do
			((columnas=columnas+${maxcols[$finalizado,$pag]}+1))
			#si se pasa de ancho 
			if [[ $columnas -gt $anchura ]]; then
				((aux++))
				columnas=0
				resumenfallos[$aux,0]=""
			fi
			#imprimir páginas
			resumenfallos[$aux,0]="${resumenfallos[$aux,0]}$( printf " %b%*s\e[0m" "$estilo" "${maxcols[$finalizado,$pag]}" "${pagFichero[$finalizado,$pag]}" )"
	done
	
	#Imprimir tabla
	lel=1 
	for (( i=0; i < ${nMarcos[$finalizado]} ; i++ ))
	do
		marco="${procesoMarcos[$finalizado,$i]}"
		
		aux=0
		columnas=0
		resumenfallos[$aux,$lel]=""

		estilo="\e[1;3${colorjastag[$finalizado]}m"

		#Primera columna (los marcos M_)
		((columnas=columnas+3+colsM))
		#comprobar si cabe
		if [[ $columnas -gt $anchura ]];then
			((aux++))
			columnas=1
			resumenfallos[$aux,$lel]=""
		fi
		#imprimir marco
		resumenfallos[$aux,$lel]=${resumenfallos[$aux,$lel]}"$( printf "%bM%0*d\e[0m " "$estilo" "$colsM" "$marco" )"
		
		#Resto de columnas (las celdas bit-pag)
		#por cada pagina
		for (( pag=0 ; pag < ${npagsProcesos[$finalizado]} ; pag++ ));do
				
				 #si la pagina del marco es la pági na que ha entrado
				if [[ "${resumenPaginas[$pag,$marco]}" -eq "${pagFichero[$finalizado,$pag]}" ]]; then
					#solo color del proceso, sin negrita
					estilo="\e[3${colorjastag[$finalizado]}m"
				 else
					#negrita y color de proceso
					# estilo="\e[1;3${colorjastag[$finalizado]}m"
					estilo="\e[1;3${colorjastag[$finalizado]}m"
				fi

				#si el marco es al que apunta el reloj
				if [[ $marco -eq ${resumenPuntero[$pag]} ]];then
					#subrayar, negrita y color de proceso
					estilo="\e[4m$estilo"
				fi

				#si la página del marco es la página que ha entrado y no son null
				if [[ -n ${resumenPaginas[$pag,$marco]} ]] && [[ "${resumenPaginas[$pag,$marco]}" -eq "${pagFichero[$finalizado,$pag]}" ]];then
					#imprimir la página y el bit
					celda="$( printf "%s=%0*d" "${resumenBit[$pag,$marco]}" "${colsP[$finalizado,$pag]}" "${resumenPaginas[$pag,$marco]}" )"
				 	#si habido fallo al meter esa páginaen esa pagina y el marco tiene página
				elif [[ ${paginaFallo[$finalizado,$pag]} == "F" ]] && [[ -n ${resumenPaginas[$pag,$marco]} ]]; then
					#imprimir la página y el bit
					celda="$( printf "%s-%0*d" "${resumenBit[$pag,$marco]}" "${colsP[$finalizado,$pag]}" "${resumenPaginas[$pag,$marco]}" )"
				# si hay pagina en el marco y el bit ha cambiado
				elif [[ -n ${resumenPaginas[$pag,$marco]} ]] && [[ $pag -gt 0 ]] && [[ ${resumenBit[$pag,$marco]} -ne ${resumenBit[$(( pag - 1 )),$marco]} ]]; then 
					#imprimir la página y el bit
					celda="$( printf "%s-%0*d" "${resumenBit[$pag,$marco]}" "${colsP[$finalizado,$pag]}" "${resumenPaginas[$pag,$marco]}" )"
				else 
					#Imprimir espacio vacío
					celda="$( printf "%*s" "${maxcols[$finalizado,$pag]}" " " )"
				fi
			
			#incrementar el numero de columnas ocupadas
			((columnas=columnas+1+${maxcols[$finalizado,$pag]}))
			#comprobar si cabe en la linea
			if [[ $columnas -gt $anchura ]];then
				((aux++))
				columnas=1
				resumenfallos[$aux,$lel]=""
			fi
			#imprimir la celda de forma que ocupe lo que debe.
			resumenfallos[$aux,$lel]=${resumenfallos[$aux,$lel]}"$( printf " $estilo%-*s\e[0m" ${maxcols[$finalizado,$pag]} "$celda" )"
		done
		((lel++))
	done

	columnas=$((3+colsM))
	aux=0
	#imprimir última linea que indica los fallos 
	for ((pag=0;pag<${npagsProcesos[$finalizado]};pag++))
	do		
		[[ $pag = "0" ]] && resumenfallos[$aux,$lel]=$( printf "  %*s " "$colsM" " " )
		#si se pasa de ancho 
		((columnas=columnas+1+${maxcols[$finalizado,$pag]}))
		if [[ $columnas -gt $anchura ]]; then
			((aux++))
			columnas=1
			resumenfallos[$aux,$lel]=""
		fi
		if [[ ${paginaFallo[$finalizado,$pag]} = "F" ]];then
			#imprimir F
			resumenfallos[$aux,$lel]=${resumenfallos[$aux,$lel]}"$( printf " %b%*s\e[0m" "\e[1;3${colorjastag[$finalizado]}m" "${maxcols[$finalizado,$pag]}" "F " )"
		else 
			#imprimir vacío
			resumenfallos[$aux,$lel]=${resumenfallos[$aux,$lel]}"$( printf " %b%*s\e[0m" "\e[1;3${colorjastag[$finalizado]}m" "${maxcols[$finalizado,$pag]}" " " )"
		fi
	done

	#Imprimir todo
	for ((l=0;l<=aux;l++)); do
		for ((m=0;m<=lel;m++)); do
			printf "\n %s" "${resumenfallos[$l,$m]}"
		done
	done
	echo
}

# DES: Mostrar cola de ejecución
imprime_cola() {
    echo -n -e " Cola de ejecución:"
    
	if [ ${#colaEjecucion[@]} -eq 0 ];then
		echo
        return 1 ;
    fi

	for proc in "${colaEjecucion[@]}";do
        echo -n -e " \e[1;3${colorjastag[$proc]}m${Ref[$proc]}\e[0m"
    done
    echo
}

imprime_reubicacion(){
	# Si no se ha producido reubicación salir sin mostrar nada
    if [ $reubicacion -ne 1 ];then
        return
    fi
	echo -n " Se ha realizado reubicación"

	local -A barraPre
	local formato="\e[1;3${colorjastag[${memoriaProcesos[$counter]}]}m"
	local anchoUnidadReubicacion=3
	local anchoprebarra=4
	local anchopostbarra=$((5+${#marcosTotales}))
	local p=0
	local aux=0
	local l=0
	local columnas=0

 #BARRA PREV 
	#por cada marco
	for (( marco = 0; marco < marcosTotales; marco++ ))
	do	
		#si hay un proceso 
		if [[ -n ${memoriaProcesoPrevia[$marco]} ]] ;then
			#meter el proceso en una variable (por comodidad)
			p=${memoriaProcesoPrevia[$marco]}
		fi

		#Incrementar el contador en el numero de caracteres que ocupe lo que hay que escribir.
		((columnas=$columnas+$anchoUnidadReubicacion))
		#comprobar si cabe lo que quiero escribir
		if [[ $columnas -gt $((anchura-anchopostbarra)) ]]
		then	#si no cabe, incrementar la linea.
			((aux++))
			#inicializar la nueva linea con 5 espacios para que guarde el margen
			columnas=$((anchoprebarra+1))
			barraPre[$aux,0]=""
			barraPre[$aux,1]=""
			barraPre[$aux,2]=""
			bool=0
		fi

	 #Procesos
		l=0

		formato="\e[1;3${colorjastag[$p]}m"
		#si el marco está ocupado y es el primer marco del proceso que lo ocupa
		if [[ -n ${memoriaProcesoPrevia[$marco]} ]] && [[ $marco -eq "${marcoInicialPrev[$p]}" ]]; then
			barraPre[$aux,$l]="${barraPre[$aux,$l]}$( printf "%b%-*s\e[0m" "$formato" "$anchoUnidadReubicacion" "${Ref[$p]}" )"
			else
			barraPre[$aux,$l]="${barraPre[$aux,$l]}$( printf "%*s" "$anchoUnidadReubicacion" " " )"
		fi

	 #Barra del medio
		l=1
		#si el marco esta vacío
		if [[ -z ${memoriaProcesoPrevia[$marco]} ]] ;then
			formato="\033[100m\033[30m"
			else
			formato="\e[4${colorjastag[$p]}m\e[30m"
		fi
		#poner el color de fondo y escribir un -
		barraPre[$aux,$l]="${barraPre[$aux,$l]}$( printf "%b%*s\e[0m" "$formato" "$anchoUnidadReubicacion" "-" )"

	 #Barra de marcos
		l=2;
		#si el marco es el primer marco del proceso que lo ocupa o es el primero vacío despues de un proceso
		if [[ $marco -eq "${marcoInicialPrev[$p]}" ]] || [[ $marco = 0 ]] || [[ $bool = 0 ]]; then
			barraPre[$aux,$l]="${barraPre[$aux,$l]}$( printf "%*s" "$anchoUnidadReubicacion" "$marco" )"
			else 
			barraPre[$aux,$l]="${barraPre[$aux,$l]}$( printf "%*s" "$anchoUnidadReubicacion" " " )"
		fi
		bool=1
		[[ $marco = "$(( ${marcoInicialPrev[$p]} + ${nMarcos[$p]} - 1))" ]] && bool=0
	done

	for (( i=0;i<=$aux;i++ ))
	do	
		for ((j=0 ; j<=l ; j++)); do
			if [[ $j -eq 1 ]] && [[ $i -eq 0 ]]; then
				printf "\n %-*s|" "$anchoprebarra" "PRE"
				elif [[ $i -eq 0 ]]; then
				printf "\n %*s|" "$anchoprebarra" " "
				else 
				printf "\n %*s " "$anchoprebarra" " "
			fi
			printf "%s" "${barraPre[$i,$j]}"
			if [[ $i -eq $aux ]]; then
			printf "|"
			fi
		done
	done

 #BARRA ACTUAL barraPos
	declare -A barraPos
 	aux=0
	l=0
	columnas=0
	#por cada marco
	for (( marco = 0; marco < marcosTotales; marco++ ))
	do	
		#si hay un proceso 
		if [[ -n ${memoriaProcesoReubicada[$marco]} ]] ;then
			#meter el proceso en una variable (por comodidad)
			p=${memoriaProcesoReubicada[$marco]}
		fi

		#Incrementar el contador en el numero de caracteres que ocupe lo que hay que escribir.
		((columnas=$columnas+$anchoUnidadReubicacion))
		#comprobar si cabe lo que quiero escribir
		if [[ $columnas -gt $((anchura-anchopostbarra)) ]]
		then	#si no cabe, incrementar la linea.
			((aux++))
			#inicializar la nueva linea con 5 espacios para que guarde el margen
			columnas=$((anchoprebarra+1))
			barraPos[$aux,0]=""
			barraPos[$aux,1]=""
			barraPos[$aux,2]=""
			flag=0
		fi

	 #Procesos
		l=0
		formato="\e[1;3${colorjastag[$p]}m"
		#si el marco está ocupado y es el primer marco del proceso que lo ocupa
		if [[ -n ${memoriaProcesoReubicada[$marco]} ]] && [[ $marco -eq "${marcoInicial[$p]}" ]]; then
			barraPos[$aux,$l]="${barraPos[$aux,$l]}$( printf "%b%-*s\e[0m" "$formato" "$anchoUnidadReubicacion" "${Ref[$p]}" )"
			else
			barraPos[$aux,$l]="${barraPos[$aux,$l]}$( printf "%*s" "$anchoUnidadReubicacion" " " )"
		fi

	 #Barra del medio
	 	l=1
		#si el marco esta vacío
		if [[ -z ${memoriaProcesoReubicada[$marco]} ]] ;then
			formato="\033[100m\033[30m"
			else
			formato="\e[4${colorjastag[$p]}m\e[30m"
		fi
		#poner el color de fondo y escribir un -
		barraPos[$aux,$l]="${barraPos[$aux,$l]}$( printf "%b%*s\e[0m" "$formato" "$anchoUnidadReubicacion" "-" )"

	 #Barra de marcos
	 	l=2;
		#si el marco es el primer marco del proceso que lo ocupa o es el primero vacío despues de un proceso
		if [[ $marco -eq "${marcoInicial[$p]}" ]] || [[ $marco = 0 ]] || [[ $flag = 0 ]]; then
			barraPos[$aux,$l]="${barraPos[$aux,$l]}$( printf "%*s" "$anchoUnidadReubicacion" "$marco" )"
			else 
			barraPos[$aux,$l]="${barraPos[$aux,$l]}$( printf "%*s" "$anchoUnidadReubicacion" " " )"
		fi
		flag=1
		[[ $marco = "${marcoFinal[$p]}" ]] && flag=0
	done

	for (( i=0;i<=$aux;i++ ))
	do	
		for ((j=0 ; j<=l ; j++)); do
			if [[ $j -eq 1 ]] && [[ $i -eq 0 ]]; then
				printf "\n %-*s|" "$anchoprebarra" "POS"
				elif [[ $i -eq 0 ]]; then
				printf "\n %*s|" "$anchoprebarra" " "
				else 
				printf "\n %*s " "$anchoprebarra" " "
			fi
			printf "%s" "${barraPos[$i,$j]}"
			if [[ $i -eq $aux ]]; then
			printf "|"
			fi
		done
	done
	echo
}

# des: calcula el tamaño que deben tener ciertas columnas y lo guarda en variables, que luego se usarán en las funciones correspondientes
calculaEspacios(){
	((num= marcosTotales-1 ))
	((anchoMarcosMax=${#num}+1))
 #plan: calcular los espacios de las columnas de los imprimeprocesos

 #RESUMEN MARCOS
	for ((m=0;m<marcosTotales;m++));do
	anchoResumenMarco[$m]=2
	# si la referencia del marco(M00) ocupa más de 3 huecos
	[[ $((${#m}+1)) -ge "3" ]] && anchoResumenMarco[$m]=$((${#m}+1))
	[[ ${#memoriaPagina[$m]} -gt ${anchoResumenMarco[$m]} ]] && anchoResumenMarco[$m]=${#memoriaPagina[$m]}
	done

 #BARRAS DE REUBICACIÓN
	anchoUnidadReubicacion=3 #minimo 3 q es lo que ocupan los nombres de los procesos
	#comprobar tb el ancho de los marcos
	[[ $anchoMarcosMax -gt $anchoUnidadReubicacion ]] && anchoUnidadReubicacion=$anchoMarcosMax

 #BARRAS DE MEMORIA Y TIEMPO.
	#inicializar variable
	anchoUnidadBarras=3
	#comprobar el ancho del numero de marco
	[[ $anchoMarcosMax -gt $anchoUnidadBarras ]] && anchoUnidadBarras=$anchoMarcosMax
	#recorrer el ancho de todas las páginas
	for pagina in "${pagFichero[@]}"; do
	[[ ${#pagina} -ge $anchoUnidadBarras ]] && anchoUnidadBarras=$((${#pagina}+1))
	done
	#comprobar el ancho del tiempo
	[[ ${#t} -ge $anchoUnidadBarras ]] && anchoUnidadBarras=$((${#t}+1))
}

imprime_marcos(){
	local anchopostbarra=$((5+${#marcosTotales}))
	local espacios=0
	local formato=""
	declare -A resumenmarcos
	local aux=0
	local l
	local columnas=1
	echo -n " Marcos de página "

	#inicializar vector
	resumenmarcos[$aux,0]=""	#linea de procesos
	resumenmarcos[$aux,1]=""	#linea de marcos
	resumenmarcos[$aux,2]=""	#linea de páginas
	resumenmarcos[$aux,3]=""	#linea de coeficientes


	for (( marco=0 ; marco<marcosTotales; marco++ )); do
		#si hay un proceso 
		if [[ -n ${memoriaProceso[$marco]} ]] ;then
			#metemos el proceso en una variable (por comodidad)
			p=${memoriaProceso[$marco]}
		fi

		#Incrementar el contador en el numero de caracteres que ocupe lo que hay que escribir.
		((columnas=columnas+${anchoResumenMarco[$marco]}+1))
		#comprobar si cabe lo que quiero escribir
		if [[ $columnas -gt $anchura ]]
		then	#si no cabe, incrementar la linea.
			((aux++))
			#inicializar la nueva linea 
			columnas=1
			resumenmarcos[$aux,0]=""
			resumenmarcos[$aux,1]=""
			resumenmarcos[$aux,2]=""
			resumenmarcos[$aux,3]=""
		fi

	 #Procesos
		l=0
		formato="\e[1;3${colorjastag[$p]}m"
		#si el marco está ocupado y es el primer marco del proceso que lo ocupa
		if [[ -n ${memoriaProceso[$marco]} ]] && [[ $marco -eq "${marcoInicial[$p]}" ]]; then
			espacios=1
			[[ ${anchoResumenMarco[$marco]} -lt "3" ]] && espacios=0
			resumenmarcos[$aux,$l]="${resumenmarcos[$aux,$l]}$( printf "%b%-*s\e[0m%*s" "$formato" "${anchoResumenMarco[$marco]}" "${Ref[$p]}" "$espacios" "" )"
			else
			resumenmarcos[$aux,$l]="${resumenmarcos[$aux,$l]}$( printf "%*s " "${anchoResumenMarco[$marco]}" "" )"
		fi
	 #Marcos
		l=1
		#imprimimos el nombre del marco en el color del proceso que lo ocupa.
		if [[ -z ${memoriaProceso[$marco]} ]]; then
				#sin color, en negrita
				resumenmarcos[$aux,$l]=${resumenmarcos[$aux,$l]}"$( printf "\e[1m%-*s\e[0m " "${anchoResumenMarco[$marco]}" "M$marco" )"
			#si el marco es el marcosiguiente donde se van a meter páginas 
			elif [[ $marco = "$siguienteMarco" ]];then	
				#color y subrayar
				resumenmarcos[$aux,$l]=${resumenmarcos[$aux,$l]}"$( printf "%b%-*s\e[0m " "\e[4m\e[1;3${colorjastag[$p]}m" "${anchoResumenMarco[$marco]}" "M$marco" )"
			else
				#color
				resumenmarcos[$aux,$l]=${resumenmarcos[$aux,$l]}"$( printf "%b%-*s\e[0m " "\e[1;3${colorjastag[$p]}m" "${anchoResumenMarco[$marco]}" "M$marco" )"
		fi

	 #Páginas
		l=2
		#calcular cuantos espacios dejar antes de la pagina.
		espacios=0
		#si la pagina ocupa menos que el marco, calcular cuantos espacios (lo que ocupa el Mmarco - lo que ocupa la pagina)
		[[ ${#memoriaPagina[$marco]} -lt ${anchoResumenMarco[$marco]} ]] && espacios=$(( ${anchoResumenMarco[$marco]}-${#memoriaPagina[$marco]} ))
		
		#imprimimos la página en el color del proceso que ocupa el marco.
		#si el marco es el marcosiguiente donde se van a meter páginas 
		if [[ $marco = "$siguienteMarco" ]];then	
			#añadir subrayado al formato.
			formato="\e[4m\e[1;3${colorjastag[$p]}m"
			elif [[ -n ${memoriaProceso[$marco]} ]];then
			#formato normal(color del proceso) en negrita
			formato="\e[1;3${colorjastag[$p]}m"
			else
			formato="\e[0m"
		fi
		# si no hay proceso
		if [[ -z ${memoriaProceso[$marco]} ]]; then 	# vacío
			resumenmarcos[$aux,$l]=${resumenmarcos[$aux,$l]}"$( printf "%*s%b%s\e[0m " "$espacios" "" "$formato" "" )"
		# si no hay página
		elif [[ -z ${memoriaPagina[$marco]} ]]; then 	# guión
			espacios=$(( ${#marco} ))
			resumenmarcos[$aux,$l]=${resumenmarcos[$aux,$l]}"$( printf "%*s%b%s\e[0m " "$espacios" "" "$formato" "-" )"
		else # página
			resumenmarcos[$aux,$l]=${resumenmarcos[$aux,$l]}"$( printf "%*s%b%s\e[0m " "$espacios" "" "$formato" "${memoriaPagina[$marco]}" )"
		fi
	 #Coeficientes
		l=3

		if [[ -n ${memoriaBitR[$marco]} ]]; then
			resumenmarcos[$aux,$l]="${resumenmarcos[$aux,$l]}$( printf "%b%*s \e[0m" "\e[1;3${colorjastag[$p]}m" "${anchoResumenMarco[$marco]}" "${memoriaBitR[$marco]}" )"
			elif [[ ${memoriaProceso[$marco]} -eq $enEjecucion ]] && [[ -n ${memoriaProceso[$marco]} ]];then
			resumenmarcos[$aux,$l]="${resumenmarcos[$aux,$l]}$( printf "%*s " "${anchoResumenMarco[$marco]}" "-")"
			else
			resumenmarcos[$aux,$l]="${resumenmarcos[$aux,$l]}$( printf "%*s " "${anchoResumenMarco[$marco]}" "")"
		fi

	 # Datos extra del numero de marcos
		#si el marco es el último
		if [[ $marco = $((marcosTotales-1)) ]];then
			#contar tambien lo que va a ocupar M=...
			((columnas=columnas+4+${#marco}))

			#comprobar si cabe lo que quiero escribir
			if [[ $columnas -gt $anchura ]]
			then	#si no cabe, incrementar la linea.
				((aux++))
				#inicializar la nueva linea con 5 espacios para que guarde el margen
				columnas=1
				barraMem[$aux,1]=" "
			fi
				#si el marco es el último
			resumenmarcos[$aux,1]=${resumenmarcos[$aux,1]}"$( printf "| M=%s" "$marcosTotales" )"
		fi
	
	done

	#imprimir todo
	for (( i=0;i<=aux;i++ )); do
		for ((j=0 ; j<=l ; j++)); do
			printf "\n %s" "${resumenmarcos[$i,$j]}"
		done
	done
	echo ""
}

#des: muestra el estado de la memoria en cada instante
imprime_barra_memoria(){ 
	local -A barraMem
	local formato="\e[1;3${colorjastag[${memoriaProcesos[$counter]}]}m"
	local anchoprebarra=3
	local anchopostbarra=$((5+${#marcosTotales}))
	local p=0
	local aux=0
	local l=0
	local columnas=0
	
	#por cada marco
	for (( marco = 0; marco < marcosTotales; marco++ ))
	do	
		#si hay un proceso 
		if [[ -n ${memoriaProceso[$marco]} ]] ;then
			#meter el proceso en una variable (por comodidad)
			p=${memoriaProceso[$marco]}
		fi

		#si es el primer marco
		if [[ $marco = 0 ]];then
			#Inicializar barras
			barraMem[$aux,0]="$( printf "%*s|" "$anchoprebarra" " " )"
			barraMem[$aux,1]="$( printf "%-*s|" "$anchoprebarra" "BM " )"
			barraMem[$aux,2]="$( printf "%*s|" "$anchoprebarra" " " )"
			((columnas=$anchoprebarra+2))
		fi

		#comprobar si va a caber algo más
		if [[ $columnas -gt $(($anchura-$anchoUnidadBarras)) ]]
		then	#si no cabe, incrementar la linea.
			((aux++))
			#inicializar la nueva linea con 5 espacios para que guarde el margen
			columnas=$((anchoprebarra+1))
			barraMem[$aux,0]="    "
			barraMem[$aux,1]="    "
			barraMem[$aux,2]="    "
			flag=0
		fi

	 #Procesos
		l=0
		formato="\e[1;3${colorjastag[$p]}m"
		#si el marco está ocupado y es el primer marco del proceso que lo ocupa
		if [[ -n ${memoriaProceso[$marco]} ]] && [[ $marco -eq "${marcoInicial[$p]}" ]]; then
			barraMem[$aux,$l]="${barraMem[$aux,$l]}$( printf "%b%-*s\e[0m" "$formato" "$anchoUnidadBarras" "${Ref[$p]}" )"
			else
			barraMem[$aux,$l]="${barraMem[$aux,$l]}$( printf "%*s" "$anchoUnidadBarras" " " )"
		fi

	 #Barra del medio
	 	l=1
		#si el marco esta vacío
		if [[ -z ${memoriaProceso[$marco]} ]] ;then
			formato="\e[47m\e[30m"
			else
			formato="\e[4${colorjastag[$p]}m\e[30m"
		fi
		#si la pagina está vacía
		if [[ -z ${memoriaPagina[$marco]} ]] ;then
			#poner el color de fondo y escribir un -
			barraMem[$aux,$l]="${barraMem[$aux,$l]}$( printf "%b%*s\e[0m" "$formato" "$anchoUnidadBarras" "-" )"
			else
			#poner el color y escribir la página que ocupa ese marco
			barraMem[$aux,$l]="${barraMem[$aux,$l]}$( printf "%b%*s\e[0m" "$formato" "$anchoUnidadBarras" "${memoriaPagina[$marco]}" )"
		fi

	 #Barra de marcos
	 	l=2;
		#si el marco es el primer marco del proceso que lo ocupa o es el primero vacío despues de un proceso
		if [[ $marco -eq "${marcoInicial[$p]}" ]] || [[ $marco = 0 ]] || { [[ $flag = 0 ]] && [[ -z ${memoriaProceso[$marco]} ]] ;}; then
			barraMem[$aux,$l]="${barraMem[$aux,$l]}$( printf "%*s" "$anchoUnidadBarras" "$marco" )"
			else 
			barraMem[$aux,$l]="${barraMem[$aux,$l]}$( printf "%*s" "$anchoUnidadBarras" " " )"
		fi
		flag=1
		[[ -n ${memoriaProceso[$marco]} ]] && [[ $marco -eq "${marcoFinal[$p]}" ]] && flag=0

	#Incrementar el contador en el número de caracteres que ocupe lo que se haya escrito.
		((columnas=$columnas+$anchoUnidadBarras))

		#si el marco es el último
		if [[ $marco = $((marcosTotales-1)) ]];then

			#comprobar si cabe lo que quiero escribir
			if [[ $columnas -gt $(($anchura-$anchopostbarra)) ]]
			then	#si no cabe, incrementar la linea.
				((aux++))
				#inicializar la nueva linea con 5 espacios para que guarde el margen
				columnas=$((anchoprebarra+1))
				barraMem[$aux,0]="    "
				barraMem[$aux,1]="    "
				barraMem[$aux,2]="    "
			fi
		
			barraMem[$aux,0]="${barraMem[$aux,0]}$( printf "|" )"
			barraMem[$aux,1]="${barraMem[$aux,1]}$( printf "|%s" " M=$marcosTotales" )"
			barraMem[$aux,2]="${barraMem[$aux,2]}$( printf "|" )"
			((columnas=$columnas+$anchopostbarra))
			break
		fi
	done
	#imprimir todo
	for (( i=0;i<=aux;i++ )); do	
		for ((j=0 ; j<=l ; j++)); do
			printf "\n %s" "${barraMem[$i,$j]}"
		done
	done
}

#des: muestra de cada instante, el proceso y la página que se ejecuta
imprime_barra_tiempo(){
	local -A barraT
	local formato="\e[1;3${colorjastag[${tiempoProceso[$tiempo]}]}m"
	local anchoprebarra=3
	local anchopostbarra=$((5+${#marcosTotales}))
	local p=0		#proceso en ese marco
	local aux=0		#para saber cuantas veces se salta de linea pq la barra no cabe en la pantalla
	local l=0		#que linea estamos, hay 3
	local columnas=0		#contador de las columnas que se han ocupado

	#por cada tiempo
	for (( tiempo = 0; tiempo <=$t; tiempo++ ))
	do
		# #si hay un proceso 
		if [[ -n ${tiempoProceso[$tiempo]} ]] ;then
			#meter el proceso en una variable (por comodidad)
			p=${tiempoProceso[$tiempo]}
		fi

		#si es el primer instante
		if [[ $tiempo = 0 ]];then
			#Inicializar barras
			barraT[$aux,0]="$( printf "%*s|" "$anchoprebarra" " " )"
			barraT[$aux,1]="$( printf "%-*s|" "$anchoprebarra" "BT " )"
			barraT[$aux,2]="$( printf "%*s|" "$anchoprebarra" " " )"
			((columnas=$anchoprebarra+2))
		fi

		#comprobar si cabe otra unidad
		if [[ $columnas -gt $(($anchura-$anchoUnidadBarras)) ]] || [[ $columnas -gt "124" ]]
		then	#si no cabe, incrementar la linea.
			((aux++))
			#inicializar la nueva linea con 5 espacios para que guarde el margen
			columnas=$((anchoprebarra+2+$anchoUnidadBarras))
			barraT[$aux,0]="    "
			barraT[$aux,1]="    "
			barraT[$aux,2]="    "
		
		fi

	 #Procesos
		l=0
		formato="\e[1;3${colorjastag[$p]}m"
		#si el en ese tiempo hay un proceso en ejecución y es el tiempo en el que ha iniciado la ejecución el proceso
		if [[ -n ${tiempoProceso[$tiempo]} ]] && [[ $tiempo -eq "${procesotInicio[$p]}" ]]; then
			barraT[$aux,$l]="${barraT[$aux,$l]}$( printf "%b%-*s\e[0m" "$formato" "$anchoUnidadBarras" "${Ref[$p]}" )"
			else
			barraT[$aux,$l]="${barraT[$aux,$l]}$( printf "%*s" "$anchoUnidadBarras" " " )"
		fi

	 #Barra del medio
	 	l=1
		#si si que hay proceso y no es el tiempo actual
		if [[ -n ${tiempoProceso[$tiempo]} ]] && [[ $tiempo -ne $t ]];then
			#barra del color del proceso y letras neutras
			formato="\e[4${colorjastag[$p]}m\e[30m"
			elif [[ -n ${tiempoPagina[$tiempo]} ]] && [[ $tiempo -eq $t ]];then
			#solo letras del color del proceso
			formato="\e[3${colorjastag[$p]}m"
			else
			#barra blanca
			formato="\e[47m\e[30m"
		fi

		#si la pagina está vacía
		if [[ -z ${tiempoPagina[$tiempo]} ]] ;then
			#poner el color de fondo y escribir un -
			barraT[$aux,$l]="${barraT[$aux,$l]}$( printf "%b%*s\e[0m" "$formato" "$anchoUnidadBarras" " " )"
			else
			#poner el color y escribir la página que ocupa ese marco
			barraT[$aux,$l]="${barraT[$aux,$l]}$( printf "%b%*s\e[0m" "$formato" "$anchoUnidadBarras" "${tiempoPagina[$tiempo]}" )"
		fi
	 #Barra de tiempos
	 	l=2;
		#si el tiempo es el de entrada del proceso o es el primero vacío despues de un proceso
		if [[ $tiempo -eq "${procesotInicio[$p]}" ]] || [[ $tiempo = 0 ]] || [[ $tiempo -eq ${procesotFin[$p]} ]]; then
			barraT[$aux,$l]="${barraT[$aux,$l]}$( printf "%*s" "$anchoUnidadBarras" "$tiempo" )"
			else 
			barraT[$aux,$l]="${barraT[$aux,$l]}$( printf "%*s" "$anchoUnidadBarras" " " )"
		fi
		

	 #Incrementar el contador en el numero de caracteres que ocupe lo que hay que escribir.
		((columnas=$columnas+$anchoUnidadBarras))

		#si el marco es el último
		if [[ $tiempo -eq $t ]];then
		
			#comprobar si cabe lo que quiero escribir
			if [[ $columnas -gt $(($anchura-$anchopostbarra)) ]]
			then	#si no cabe, incrementar la linea.
				((aux++))
				#inicializar la nueva linea con 5 espacios para que guarde el margen
				columnas=$((anchoprebarra+1))
				barraT[$aux,0]="    "
				barraT[$aux,1]="    "
				barraT[$aux,2]="    "
			fi

			barraT[$aux,0]="${barraT[$aux,0]}$( printf "|" )"
			barraT[$aux,1]="${barraT[$aux,1]}$( printf "|%s" " T=$t" )"
			barraT[$aux,2]="${barraT[$aux,2]}$( printf "|" )"

			#contar tambien lo que va a ocupar M=...
			((columnas=$columnas+$anchopostbarra))
			break
		fi
	done

	for (( i=0;i<=$aux;i++ ));do	
		for ((j=0 ; j<=l ; j++)); do
			printf "\n %s" "${barraT[$i,$j]}"
		done
	done
	echo
}

# DES: resetea las variables de evento para que no se vuelvan a mostrar
limpiar_eventos() {

		# No seguir mostrando la pantalla
		mostrarPantalla=0
		reubicacion=0

		llegada=()
		entrada=()
		iniciado=""

		# Si ha finalizado un proceso
		if [[ -n "${finalizado}" ]];then
			resumenPaginas=()
			resumenBit=()
			resumenPuntero=()
			# Por si entra un proceso a la vez que sale
			local corte=${tiempoEjec[$finalizado]}
			marcoFallo=("${marcoFallo[@]:$corte}")

			finalizado=""
		fi
}

#Funcion que muestra al final los fallos y tiempos
imprime_resumenfinal(){
	tot=0
		media 'tiempoEspera[@]'
		mediaespera="$lamedia"
		media 'tiempoRetorno[@]'
		mediadura="$lamedia"
		lamedia=0;
	clear

	echo -e "T.ESPERA:     Tiempo que el proceso no ha estado ejecutándose en la CPU desde que entra en memoria hasta que sale"
	echo -e "ESPERA TOTAL: Tiempo que el proceso no ha estado ejecutándose en la CPU desde T=0 (Inicio del sistema) hasta que sale"
	echo -e "INICIO/FIN:   Tiempo de llegada al gestor de memoria del proceso y tiempo de salida del proceso"
	echo -e "T.RETORNO:    Tiempo total de ejecución del proceso, incluyendo tiempos de espera, desde la señal de entrada hasta la salida"

	echo
	echo -e "RESUMEN FINAL con tiempos de ejecución y fallos de página de cada proceso"

	echo -e "     Proceso	    T.Espera	   Inicio/Fin	    T.Retorno	    Fallos de página"

	echo -e "———————————————————————————————————————————————————————————————————————————————————"
	# mediaespera=0
	for (( counter=0; counter < $numProcesos; counter++ ))
		do
		((tot++))
		echo -e " 	\e[1;3${colorjastag[$counter]}m${Ref[$counter]}\e[0m	 	\e[1;3${colorjastag[$counter]}m${tiempoEspera[$counter]}\e[0m	      \e[1;3${colorjastag[$counter]}m${procesotInicio[$counter]}/${procesotFin[$counter]}\e[0m	 	\e[1;3${colorjastag[$counter]}m${tiempoRetorno[$counter]}\e[0m	         \e[1;3${colorjastag[$counter]}m${numFallos[$counter]}\e[0m"
	done
		
	# mediaespera=`(echo "scale=3;$mediaespera/ $tot" | bc -l)`

	echo ""
	echo -ne "   \e[1;31mTiempo total\e[0m transcurrido en ejecutar todos los procesos: \e[1;31m$t\e[0m"
	printf "\n   \e[1;31mMedia tiempo espera\e[0m  de todos los procesos: \e[1;31m%-6s\e[0m" "$mediaespera"
	printf "\n   \e[1;31mMedia tiempo retorno\e[0m de todos los procesos: \e[1;31m%-6s\e[0m" $mediadura
	echo ""
	{
	echo
	echo
	echo "|———————————————————————————————————————————————————————————————|--------------------->"; } | tee -a "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE" >> "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"
	echo 
}

### Fin de funciones de volcado en pantalla ####
################################################

#des: da formato final a los informes, gestiona las opciones del final del programa.
final(){
	local editor=0;
	local menufin
	local num=0;					#usado en la sustitución de caracteres, cuenta el número de lineas del fichero
	clear
	if [[ $dondeinformes != 3 ]]; then
	 #Formato informes
		# quitar los 'clean' del informe a color
		sed -i 's/\x1B\[H\x1B\[2J\x1B\[3J//g' "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE"
		#crear informe en blanco y negro
		#sustituir los colores de las barras de memoria y tiempo por _ y *
		for (( i=anchoUnidadBarras ; i>0 ; i--));do
		sed -i -r "s/[[:cntrl:]]\[47m([[:cntrl:]]\[30m)?[ ]{$i}/$(printf "%${i}s" "" | tr " " "*")/g" "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"
		sed -i -r "s/[[:cntrl:]]\[4[0-9]m([[:cntrl:]]\[(30|97)m)?[ ]{$i}/$(printf "%${i}s" "" | tr " " "_")/g" "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"	
		done
		#quitar todo el formato
		sed -i 's/[[:cntrl:]]\[\(;*[0-9][0-9]*\)*[fhlmpsuABCDEFGHJKST]//g' "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"

		echo
		echo -e "\e[1;32mSe han guardado los informes. Puedes encontrarlos en\e[0m \e[1;33m'$CARPETA_INFORMES'\e[0m "
		echo
	fi

	while :; do
		echo -e "\e[1;38;5;81m¿Qué quiere hacer ahora?\e[0m"
		echo ""
		echo -e "\e[1;33m	1\e[0m- Abrir el informe"
		echo -e "\e[1;33m	2\e[0m- Volver a ejecutar el programa"
		echo -e "\e[1;33m	3\e[0m- Salir"
		echo ""
		echo -n "Seleccione una opción: "
		read -r menufin
		until [[ $menufin = "1" || $menufin = "2" || $menufin = "3" ]]; do
				echo -e "\e[1;31m Pulse\e[0m\e[1;33m 1\e[0m, \e[1;33m 2\e[0m o\e[1;33m 3\e[0m: "
				read -r menufin
		done

		case "${menufin}" in	
			1) # Ver los informes
				echo "¿Con qué editor quiere abrir el informe? (nano, vi, [vim], gvim, gedit, atom, cat(A COLOR), otro)"
				echo "Después de visualizarlo vuelva a esta ventana"
				echo -n "Introduce: "
				read -r editor
				until [[ $editor = "nano" ||  $editor = "vi" ||  $editor = "vim" ||  $editor = "gvim" ||  $editor = "gedit" ||  $editor = "atom"  || $editor = "cat"  ||  $editor = "otro" || $editor = "" ]]
				do
					read -rp "Por favor escoja uno de la lista: (nano, vi, [vim], gvim, gedit, atom, cat, otro) : " editor
				done
				case $editor in
						"nano")
							nano "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE";;
						"vi")
							vi "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE";;
						"vim")
							vim "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE";;
						"gvim")
							gvim "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE";;
						"gedit")
							gedit "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE";;
						"atom")
							atom "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE";;
						"cat")
							cat "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE";;
						"otro")
							echo 
							echo "Al escoger otro editor tenga en cuenta que debe tenerlo instalado, sino dará error"
							leer -p "Introduzca: " editor
							echo
							$editor "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE";;
				esac
				read -r
				clear
			;;
			2)
				main
			;;
			3)
				echo
				echo
				sleep 1
				# declare -p
				cabecerafinal
				break
			;;
		esac
	done
}

# des: restaura los descriptores y da formato a los informes, es una función auxiliar controlada por una trampa, se ejecuta en caso de interruciones inesperadas del script. 
final_interrupcion(){
	# echo "final_interrupcion"
	#devolver estos a la normalidad
	exec 2>&4 1>&3
	
	if [[ $dondeinformes != 3 ]] && [[ -f "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE" ]] && [[ -f "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE" ]]; then
	 #Formato informes
		# quitar los 'clean' del informe a color
		sed -i 's/\x1B\[H\x1B\[2J\x1B\[3J//g' "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE"
		#crear informe en blanco y negro
		#sustituir los colores de las barras de memoria y tiempo por _ y *
		for (( i= anchoUnidadBarras; i>0 ; i--));do
		sed -i -r "s/[[:cntrl:]]\[47m([[:cntrl:]]\[30m)?[ ]{$i}/$(printf "%${i}s" "" | tr " " "*")/g" "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"
		sed -i -r "s/[[:cntrl:]]\[4[0-9]m([[:cntrl:]]\[(30|97)m)?[ ]{$i}/$(printf "%${i}s" "" | tr " " "_")/g" "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"	
		done
		#quitar todo el formato
		sed -i 's/[[:cntrl:]]\[\(;*[0-9][0-9]*\)*[fhlmpsuABCDEFGHJKST]//g' "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"
	fi
	exit 1
}

##############################
##  OTRAS FUNCIONES ÚTILES  ##
##############################

# DES: Lee la variable dada en raw. Se usa para que el input solo se interprete como texto
#		Mete el valor leido al informe
# RET: devuelve 0
# USO: leer var
leyendo(){
    read -r $1
	return 0
}

#Des: Función que sustituye a read. Se ha creado para facilitar mostrar read y el input del usuario en los informes. 
#solo pensada para read con nada o con -r o -p
leer() {
    local leido=""
    if [ $# -eq 3 ]; then               #si hay mensaje con el read se imprime
        echo -n "$2"
    fi
    leyendo leido
	
    #asignamos el valor leido a la variable que nos daban
	case $# in
		1 )
			if [[ "${1}" == *"-"* ]]; then
				leido=""
				else 
				eval "$1=$leido"
			fi
		;;
		2 )
			eval "$2=$leido"
		;;
		3 )
			if [[ "${1}" == "-p" ]]; then
				eval "$3=$leido"
			fi
		;;
		* )
			echo e "\e[1;31mError de lectura del input manual\e[0m"
			exit
		;;
	esac		
	if [[ -f "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE" ]] && [[ -f "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE" ]]; then
		echo "$leido" | tee -a "./$CARPETA_INFORMES/$INFORMECOLOR_NOMBRE" >> "./$CARPETA_INFORMES/$INFORMEBN_NOMBRE"
	fi
	
    return 0
}

# DES: Lee un número entre 0 y el número máximo
# RET: 0=Número válido 1=Tiene caracteres no numéricos (incluyendo "-") 2=No se ha introducido nada 3=Número demasiado grande
# USO: Se usa la siguiente estructura:
    #
    #   echo -n "Introduce un número: "
    #   # while true
    #   while :;do
    #   
    #       leer_numero num
    #       # Dependiendo del valor devuelto por la función anterior
    #       case $? in      
    #           
    #           # Valor válido
    #           0 )
    #               break
    #           ;;
    #           # Valor no número natural
    #           1 )
    #               echo -n "Aviso. Introduce un número natural: "
    #           ;;
    #           # No se ha introducido nada
    #           2 )
    #               echo -n "Aviso. Debes introducir algo:"
    #           ;;
    #           # Valor demasiado grande
    #           3 )
    #               echo -n "Aviso. Valor demasiado grando: "
    #           ;;
    #
    #       esac
    #   done
    #
leer_numero() {

    # Variable temporal en la que se guarda el valor leido
    local val
    # Leer input del usuario
    leer val

    # Eliminar 0s del principio, porque dan problemas
    # Mientras val sea más largo que 1 y el primer caracter sea 0
    while [[ "${#val}" -gt "1" && "${val:0:1}" == "0" ]];do
        # Eliminar el primer caracter
        val="${val:1}"
    done

    # Asignar el valor a $1
    eval "$1=$val"

    # Si no se ha introducido nada
    if [ ${#val} -eq 0 ];then
        return 2
    # Si se introducen valores no numéricos. Incluyendo "-"
    elif [[ ! "${val}" =~ ^[0-9]+$ ]];then
        return 1
    # Si el número es demasiado grande
    # 9223372036854775807 es el valor máximo de entero que soporta BASH. Si es sobrepasado se
    # entra a valores negativos por overflow por lo que limitando la longitud y comprobando que
    # no se han entrado a valores negativos se asegura que el valor introducido no hace overflow.
    elif [[ "${#val}" -gt 19 || "$val" -lt 0 ]] || [ "$val" -gt "$numeroMaximo" ];then
        return 3
    fi

    return 0
}

# DES: Lee un número que debe estar entre 2 valores. Usa la función anterior. El valor máximo es opcional
# RET: 0=Número válido             1=Tiene caracteres no numéricos (incluyendo "-")
#      2=No se ha introducido nada 3=Número demasiado grande 4=Número demasiado pequeño
# USO: Se usa la siguiente estructura:
    #
    #    echo -n "Introduce un número: "
    #    # while true
    #    while :;do
    #    
    #        leer_numero_entre var min max
    #        # En caso de que el valor devuelto por la función anterior
    #        case $? in
    #            
    #            # Valor válido
    #            0 )
    #                break
    #            ;;
    #            # Valor no número natural
    #            1 )
    #                echo -n "Aviso. Introduce un número natural: "
    #            ;;
    #            # No se introduce nada
    #            2 )
    #                echo -n "Aviso. Debes introducir algo: "
    #            ;;
    #            # Valor demasiado grande
    #            3 )
    #                echo -n "Aviso. Valor demasiado grande: "
    #            ;;
    #            # Valor demasiado pequeño
    #            4 )
    #                echo -n "Aviso. Valor demasiado pequeño: "
    #            ;;
    #    
    #        esac
    #    done
    #
leer_numero_entre() {
    # Se establece el mínimo y el máximo
    local min=$2
    local max

    # Si se da máximo y si no.
    [ $# -eq 3 ] && max=$3 || max=$numeroMaximo

    # Leer número 
    leer_numero $1

    # Dependiendo del valor devuelto por la función inmediatamente anterior
    case $? in
        # Valor válido
        #0 )
            # No se hace nada porque hay que compararlo más adelante   
        #;;
        # Valor no número natural
        1 )
            return 1
        ;;
        # No se ha introducido nada
        2 )
            return 2
        ;;
        # No se ha introducido nada
        3 )
            return 3
        ;;
    esac

    # Si el número introducido se pasa del mínimo
    if [ "${!1}" -lt "$min" ];then
        return 4
    # Si el número introducido se pasa del máximo
    elif [ "${!1}" -gt "$max" ];then
        return 3
    fi
	
    return 0
}

#########################################################################################

# Des: función principal
main(){
	preparativos

	#Cabecera
	cabeceraPrograma

	#pregunta si leer la ayuda o ejecutar el algoritmo
	preguntainicio
	preguntaDondeGuardarInformes
	preguntaMetodoOrdenacion
	
	#Recogida de datos
	datos
	
	pideModoEjecucion

	#Ejecución del algoritmo
	ejecucion

	#devolver los descriptores a los originales y por tanto se deja de redirigir el output al informe
	exec 2>&4 1>&3

	final
	exit 0
}

main

# en el informe hay un esquema de la estructura que sigue el script :)
# tip: si usas visual studio hay un shortcut útil que minimiza las funciones y hace más facil navegar el código: ctrl + k, ctrl + 1, para expandir de nuevo: ctrl + k, ctrl + j
