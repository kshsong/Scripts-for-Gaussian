#!/bin/bash
# This script is used to extract the results, including energies, vibrational frequencies,
# and optimized structures from Gaussian log files.
#
# 在高斯优化结构/频率计算目录下执行此脚本
# 脚本正常运行后会生成三个最终文件 Freq.out Energy.out optimized_structure.xyz
#  
# Freq.out            所有不为0的频率, 单位 cm-1
# Energy.out          电子能、零点能、电子能+零点能、吉布斯自由能校正、热力学焓校正, 单位 AU
# optimized_structure.xyz  优化后的分子结构文件

# 清理旧文件
rm -f Freq.out Energy.out optimized_structures.xyz name EE Ezpe Hcorr Gcorr freq.txt

# 遍历当前目录下的所有 .log 文件
for file in *.log; do
    # 如果文件中没有 "optimization" 关键字，则跳过
    if ! grep -q "optimization" "$file"; then
        continue
    fi

    echo "Processing $file..."

    # 检查是否正常终止
    stat=$(tail -n 1 "$file" | grep "Normal termination")
    if [ $? -eq 1 ]; then
        echo "$file is Error termination"
    fi

    # 检查是否找到稳定点
    stat1=$(grep "Stationary point found" "$file")
    if [ $? -eq 1 ]; then
        basename "$file" .log | awk '{printf "%-10s\n", $1}' >> name
        printf "%12.6f\n" 0.0 >> EE
        printf "%12.6f\n" 0.0 >> Ezpe
        printf "%12.6f\n" 0.0 >> Hcorr
        printf "%12.6f\n" 0.0 >> Gcorr
        printf "%12.6f\n" 0.0 >> EE+ZPE
    else
        basename "$file" .log | awk '{printf "%-10s\n", $1}' >> name
        grep "SCF Done" "$file" | tail -n 1 | awk '{printf "%12.6f\n", $5}' >> EE
        grep "Zero-point correction" "$file" | awk '{printf "%12.6f\n", $3}' >> Ezpe
        grep "Thermal correction to Enthalpy" "$file" | awk '{printf "%12.6f\n", $5}' >> Hcorr
        grep "Thermal correction to Gibbs Free Energy" "$file" | awk '{printf "%12.6f\n", $7}' >> Gcorr
        grep "Sum of electronic and zero-point Energies=" "$file" | awk '{printf "%12.6f\n", $NF}' >> EE+ZPE
    fi

    # 提取频率信息
    nu=$(grep "Frequencies" "$file" | grep -oP "[0-9]+\.[0-9]+" | wc -l)
    if [ $nu -eq 1 ]; then
        grep "Frequencies" "$file" | awk '{printf "%7.2f  ", $NF}' >> freq.txt
    elif [ $nu -eq 2 ]; then
        grep "Frequencies" "$file" | awk '{printf "%7.2f  %7.2f  ", $3, $NF}' >> freq.txt
    elif [ $nu -ge 3 ]; then
        grep "Frequencies" "$file" | awk '{printf "%7.2f  %7.2f  %7.2f  ", $3, $4, $NF}' >> freq.txt
    fi
    printf "\n" >> freq.txt
    # 提取优化后的分子结构
    input_orientation_line=$(grep -n "Input orientation" "$file" | tail -n 1 | cut -d: -f1)
    if [ -z "$input_orientation_line" ]; then
        echo "Error: No 'Input orientation' section found in $file."
        continue
    fi

    start_line=$((input_orientation_line + 5))
    coordinates=$(awk -v start="$start_line" '
    NR >= start {
        if ($0 ~ /----/) exit
        if (NF == 6) {
            atomic_number = $2
            x = $4
            y = $5
            z = $6
            print atomic_number, x, y, z
        }
    }' "$file")

    # 将原子序号转换为元素符号
    atomic_numbers_to_symbols() {
        case $1 in
            1) echo "H" ;;   # 氢
            6) echo "C" ;;   # 碳
            7) echo "N" ;;   # 氮
            8) echo "O" ;;   # 氮
            *) echo "X" ;;   # 未知元素
        esac
    }

    num_atoms=$(echo "$coordinates" | wc -l)

    # 获取文件名（去掉扩展名）
    base_name=$(basename "$file" .log)

    # 构造 XYZ 文件内容
    xyz_content="$num_atoms\n$base_name\n"

    while read -r line; do
        atomic_number=$(echo "$line" | awk '{print $1}')
        symbol=$(atomic_numbers_to_symbols "$atomic_number")
        x=$(echo "$line" | awk '{printf "%12.6f", $2}')
        y=$(echo "$line" | awk '{printf "%12.6f", $3}')
        z=$(echo "$line" | awk '{printf "%12.6f", $4}')
        xyz_content+="$symbol    $x    $y    $z\n"
    done <<< "$coordinates"

    # 输出到 XYZ 文件
    printf "$xyz_content" >> optimized_structures.xyz

    echo "XYZ file written to optimized_structures.xyz"
done

# 合并结果到最终文件
index="name\t\t\tEE\t\t\t\tEzpe\t\t\tEE+ZPE\t\t\tHcorr\t\t\tGcorr"
paste name EE Ezpe EE+ZPE Hcorr Gcorr | sed -r "1i$index" > Energy.out
paste name freq.txt >> Freq.out

# 清理临时文件
rm -f name EE Ezpe EE+ZPE Hcorr Gcorr freq.txt

