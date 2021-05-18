using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

Console.WriteLine("Ввод:");

int element = int.Parse(Console.ReadLine());


int count = 0;
int[] array = new int[element];
int noteven = 0;
int even = 0;
Random random = new Random();
Console.WriteLine("\n" + "Массив");
for (int i = 0; i < array.Length; i++)
{
    array[i] = random.Next(0, 25);
    Console.Write(array[i] + " ");
}

string replace1 = "";

Console.WriteLine("\n" + "Четные");
for (int i = 0; i < element; i++)
{
    if (array[i] % 2 == 0)
    {
        even = array[i];

        string text = even.ToString();
        Console.Write(text + " ");
        replace1 = text.Replace("10", "k").Replace("11", "l").Replace("12", "m").Replace("13", "n").Replace("14", "o").Replace("15", "p").Replace("16", "q").Replace("17", "r").Replace("18", "s").Replace("19", "t").Replace("20", "u").Replace("21", "v").Replace("22", "w").Replace("23", "x").Replace("24", "y").Replace("25", "z").Replace("0", "A").Replace("1", "b").Replace("2", "c").Replace("3", "D").Replace('4', 'E').Replace('5', 'f').Replace('6', 'g').Replace('7', 'H').Replace('8', 'I').Replace('9', 'J');
        Console.Write(replace1 + " ");
        
    }
    
}   

string replace2 = "";

Console.WriteLine("\n" + "Не четные");
for (int i = 0; i < element; i++)
{
    if (array[i] % 2 != 0)
    {
        noteven = array[i];


        string text2 = noteven.ToString();
        Console.Write(text2 + " ");
        replace2 = text2.Replace("10", "k").Replace("11", "l").Replace("12", "m").Replace("13", "n").Replace("14", "o").Replace("15", "p").Replace("16", "q").Replace("17", "r").Replace("18", "s").Replace("19", "t").Replace("20", "u").Replace("21", "v").Replace("22", "w").Replace("23", "x").Replace("24", "y").Replace("25", "z").Replace("0", "A").Replace("1", "b").Replace("2", "c").Replace("3", "D").Replace('4', 'E').Replace('5', 'f').Replace('6', 'g').Replace('7', 'H').Replace('8', 'I').Replace('9', 'J');
        Console.Write(replace2 + " ");
    }
}



bool temp = false;

if (temp = String.Equals(replace2, replace1, StringComparison.InvariantCulture))
{
    Console.WriteLine("\n В <не четных> больше букв в верхнем регистре");
}
else
{
    Console.WriteLine("\n В <четных> больше букв в верхнем регистре");
}


