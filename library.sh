#!/bin/bash

# checkForCmdInPath - 指定したプログラムが有効なプログラムかどうかを確認する
# 絶対パスでプログラムが指定された場合には、該当するプログラムが
# 存在するかどうかを確認し、そうでない場合には、PATHのディレクトリリスト
# にプログラムが含まれているかどうかを確認する
in_path()
{
	#コマンド名と PATH を受け取って、該当するコマンドを探す。コマンドが
	#見つかり、かつ実行可能である場合には 0 を返し、そうでない場合には
	# 1 を返す。IFS(内部フィードセパレータ)を一時的に変更するが、
	#処理を終えたらもとの値に戻している点に注意

	cmd=$1			path=$2			retval=1
	oldIFS=$IFS	IFS=":"

	for directory in $path
	do
		if [ -x $directory/$cmd ] ; then
			retval=0			# ここを通れば $direcotory で $cmd が見つかった
		fi
	done
	IFS=$oldIFS
	return $retval
}

checkForCmdInPath()
{
	var=$1

#	echo "${var%${var#?}}"
#	echo ${var%${var#?}}

	#以下で使っている ${var%${var#?}} は、変数の切り出しをネストさせて
	#いる。一般に、${var#expr} とすると、変数 var のうち expr に一致する
	#部分を var の先頭から取り除いたものが返され、${var%expr} とすると、
	#変数 var のうち expr に一致する部分を var の最後から取り除いたものが
	#返される。つまり、${var%${var#?}} は var の最初の１文字を返すことに
	#なる。bash を使っているなら ${var:0:1} としてもよい。また、cut
	#コマンドを使って cut -c1 としても最初の１文字を取り出せる

	if [ "$var" != "" ] ; then
		if [ "${var%${var#?}}" = "/" ] ; then
			if [ ! -x $var ] ; then
				return 1
			fi
		elif ! in_path $var $PATH ; then
			return 2
		fi
	fi
}


# validAlphaNum - 入力された文字列が英数字だけかどうかチェックする

validAlphaNum()
{
	# 引数が英数字だけの文字列なら 0 を返し、そうでない場合には、 1 を返す。

	# 英数字以外の文字をすべて削除する。
	compressed="$(echo $1 | sed -e 's/[^[:alnum:]]//g')"

	if [ "$compressed" != "$1" ] ; then
		return 1
	else
		return 0
	fi
}


# monthnoToName - 日付指定の月のフィールドを大文字で始まる３文字のつきの名前に
# 変換する。 終了コード 0 で終了する

monthnoToName()
{
	# 変数 month に適切な値を設定する
	case $1 in
		1 ) month="Jan"		;;	2 ) month="Feb"		;;
		3 ) month="Mar"		;;	4 ) month="Apr"		;;
		5 ) month="May"		;;	6 ) month="Jun"		;;
		7 ) month="Jul"		;;	8 ) month="Aug"		;;
		9 )	month="Sep"		;; 	10)	month="Oct"		;;
		11)	month="Nov"		;;	12) month="Dec"		;;
		* )	echo "$0: Unknown numeric month value $1" >&2; exit 1
	esac
	return 0
}


# nicenumber - 指定された数字をカンマで区切った形式に変換する。
# 関数を呼び出す前に、桁区切りの文字と小数点の区切りの文字を
# それぞれ DD と TD に設定しておく。関数の実行結果は nicenum
# に格納されるが、呼び出し時に第２引数を指定した場合には
# nicenum の値を出力する

nicenumber()
{
	
	# 入力され値は、ピリオド（.）を小数点の区切り文字と見なして
	# 処理する。-d フラグで別の値を指定された場合を除き、出力される
	# 値の小数点の区切り文字にはピリオド（.）が使われる

	separator="$(echo $1 | sed 's/[[:digit:]]//g')"
	echo "separator=${separator}"
	if [ ! -z "$separator" -a "$separator" != "$DD" ] ; then
		echo "$0: Unknown decimal separator $separator encountered." >&2
		exit 1
	fi

	integer=$(echo $1 | cut -d${separator} -f1)	# 小数点の左側を取り出す
	decimal=$(echo $1 | cut -d${separator} -f2)	# 小数点の右側を取り出す

	if [ $decimal != $1 ] ; then
		# 小数点以下の部分があれば取り込む
		result="${DD:="."}$decimal"
	fi

	thousands=$integer

	while [ $thousands -gt 999 ] ; do
		remainder=$(($thousands % 1000))	# 下３桁の数字
	
		while [ ${#remainder} -lt 3 ] ; do	# 必要に応じて先行する 0 を付加
			echo $remainder
			echo ${#remainder}
			remainder="0$remainder"
		done

		thousands=$(($thousands / 1000))	# 次の桁の処理（残っている場合）
		result="${TD:=","}${remainder}${result}"	# 右から左へ文字列を連結
		echo "result=${result}"
		echo "remainder=${remainder}"
	done

	nicenum="${thousands}${result}"
	if [ ! -z $2 ] ; then
		echo $nicenum
	fi
}

# validint - 	入力が整数値として有効かどうかを確認する
# 						負の整数も受け付ける

validint()
{
	# 最初の整数が有効かどうかを確認する。次に、もし２番目、
	# ３番目の引数が指定されていれば、それぞれの有効な値の
	# 範囲の下限と上限として扱い、その範囲に収まっているかどうかも
	# チェックする。２番目以降の引数が指定されていなければ、
	# 値の範囲のチェックは行わない。

	number=$1;	min=$2;		max=$3;

#	echo "number=${number}"

	if [ -z $number ] ; then
		echo "You didn't enter anything. Unacceptable." >&2 ; return 1
	fi

#	echo "${number#?}"
#	echo "${number%17}"
#	echo "${number%${number#?}}"
#	echo "${number:0:1}"

	if [ "${number%${number#?}}" = "-" ] ; then	# 最初の文字は"-"か
	#if [ "${number:0:1}" = "-" ] ; then	# 最初の文字は"-"か
		testvalue="${number#?}"		# 最初の文字を除いたものを testvalue とする
	else
		testvalue="$number"
	fi

#	echo "testvalue=${testvalue}"

	nodigits="$(echo $testvalue | sed 's/[[:digit:]]//g')"

	if [ ! -z $nodigits ] ; then
		echo "Invalid number format! Only digits, no commas, spaces, etc." >&2
		return 1
	fi

	if [ ! -z $min ] ; then
		if [ "$number" -lt "$min" ] ; then
			echo "Your value is too small: smallest acceptable value is $min" >&2
			return 1
		fi
	fi
	if	[ ! -z $max ] ; then
		if [ "$number" -gt "$max" ] ; then
			echo "Your value is to big: largest acceptable value is $max" >&2
			return 1
		fi
	fi
	return 0
}	

# validfloat -- 入力された浮動小数点数として有効かどうかを確認する。
# 1.304e5 など科学表記は指定はできない

# 入力された値は小数点を区切りとして２つの部分に分ける。まず、小数点の
# 左側の部分が有効な整数であるかどうかを確認する。次に、小数点の右側の
# 部分が負でない有効な整数であることを確認する（-30.5は有効だが、
# -30.-8 は無効）

validfloat()
{
	fvalue="$1"

#	echo "$(echo $fvalue | sed 's/[^.]//g')"

	if [ ! -z $(echo $fvalue | sed 's/[^.]//g') ] ; then

		decimalPart="$(echo $fvalue | cut -d. -f1)"
		fractionalPart="$(echo $fvalue | cut -d. -f2)"

#		echo "decimalPart=$decimalPart"
#		echo "fractionalPart=$fractionalPart"

		if [ ! -z $decimalPart ] ; then
			if ! validint "$decimalPart" "" "" ; then
				return 1
			fi
		fi

		if [ "${fractionalPart%${fractionalPart#?}}" = "-" ] ; then
			echo "Invalid Floating-point number: '-' not allowed after decimal point" >&2
			return 1
		fi
		if [ "$fractionalPart" != "" ] ; then
			if ! validint "$fractionalPart" "0" "" ; then
				return 1
			fi
		fi

		if [ "$decimalPart" = "-" -o -z "$decimalPart" ] ; then
			if [ -z $fractionalPart ] ; then
				echo "Invalid floating-point format." >&2 ; return 1
			fi
		fi

	else
		if [ "$value" = "-" ] ; then
			echo "Invalid floating-point format." >&2 ; return 1
		fi

		if ! validint "$fvalue" "" "" ; then
			return 1
		fi
	fi

	return 0
}

# valid-date - 入力された日付が有効かどうかを確認する。うるう年も考慮する。

exceedsDaysInMonth()
{
	# 月と日を引数として受け取り、指定された日がその月の日の範囲に収まっている
	# 場合には 0 を返し、そうでない場合には、1 を返す。

	case $(echo $1 | tr '[:upper:]' '[:lower:]') in
		jan*) days=31		;;	feb*) days=28		;;
		mar*)	days=31		;;	apr*)	days=30		;;
		may*)	days=31		;;	jun*)	days=30		;;
		jul*)	days=31		;;	aug*)	days=31		;;
		sep*)	days=30		;;	oct*)	days=31		;;
		nov*)	days=30		;;	dec)	days=31		;;
		*) echo "$0: Unknown month name $1" >&2; exit 1
	esac

	if [ $2 -lt 1 -o $2 -gt $days ] ; then
		return 1
	else
		return 0	# 有効な日
	fi
}

isLeapYear()
{
	# うるう年なら 0 を返し、そうでない場合には 1 を返す関数
	# うるう年かどうかの判定は、次のようにして行う。
	# 1. 4で割り切れない年はうるう年でない。
	# 2. 4でも400でも割り切れる年はうるう年である。
	# 3. 4で割り切れるが400で割り切れず、100で割り切れる年は、うるう年ではない。
	# 4. それ以外の4で割り切れるすべての年はうるう年である。

	year=$1
	if [ "$((year % 4))" -ne 0 ] ; then
		return 1	# うるう年でない
	elif [ "$((year % 400))" -eq 0 ] ; then
		return 0	# うるう年である
	elif [ "$((year % 100))" -eq 0 ] ; then
		return 1 
	else
		return 0
	fi
}

echon()
{
	echo -e "$*" | tr -d '\n'
}

# ANSI Color - 文字の色や字体を変更するための ANSI カラーシーケンスを
# 変数に収めて使いやすくする。変数名の末尾の f は foreground（文字）、
# b は background（背景）の意味である。

initializeANSI()
{
	esc="\033"	# これでうまくいかない場合にはESCを直接入力する

	blackf="${esc}[30m";		redf="${esc}[31m";		greenf="${esc}[32m"
	yellowf="${esc}[33m";		bluef="${esc}[34m";	purplef="${esc}[35m"
	cyanf="${esc}[36m";			whitef="${esc}[37m";

	blackb="${esc}[40m";		redb="${esc}[41m";		greenb="${esc}[45m"
	yellowb="${esc}[43m";		blueb="${esc}[44m";	purpleb="${esc}[45m"	
	cyanb="${esc}[46m"			whiteb="${esc}[47m"

	boldon="${esc}[1m"			boldoff="${esc}[22m"
	italicson="${esc}[3m";	italicsoff="${esc}[23m"
	ulon="${esc}[4m";				uloff="${esc}[24m"
	invon="${esc}[7m"				invoff="${esc}[27m"
	
	reset="${esc}[0m"
}

