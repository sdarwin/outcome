#!/bin/bash -e
GCCLINE=""
CLANGLINE=""
if [ ! -f gcc.csv ]; then
  for f in *.cpp
  do
    FILE=${f%.cpp}
    if [ "$GCCLINE" != "" ]; then
      GCCLINE=$GCCLINE,\"$FILE\"
      CLANGLINE=$CLANGLINE,\"$FILE\"
    else
      GCCLINE=\"$FILE\"
      CLANGLINE=\"$FILE\"
    fi
  done
  echo $GCCLINE >> gcc.csv
  echo $CLANGLINE >> clang.csv
fi
GCCLINE=""
CLANGLINE=""
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > results.xml
echo "<testsuite name=\"constexprs\">" >> results.xml
for f in *.cpp
do
  FILE=${f%.cpp}
  
  if [ 1 -eq 1 ]; then
    echo "Compiling ${FILE} with gcc ..."
    g++-5 -c -o $FILE.o -O3 -std=c++14 -fno-keep-inline-functions -DBOOST_SPINLOCK_MONAD_ENABLE_OPERATORS=1 -DBOOST_SPINLOCK_STANDALONE=1 -DNDEBUG -I../../include/boost/spinlock/bindlib/include $f
    objdump -d -S $FILE.o > $FILE.gcc.S

    echo "Compiling ${FILE} with clang ..."
    clang++-3.7 -Wall -Wextra -c -o $FILE.o -O3 -std=c++14 -DBOOST_CXX14_CONSTEXPR=constexpr -DBOOST_SPINLOCK_MONAD_ENABLE_OPERATORS=1 -DBOOST_SPINLOCK_STANDALONE=1 -DNDEBUG -I../../include/boost/spinlock/bindlib/include $f
    objdump -d -S $FILE.o > $FILE.clang.S
    rm $FILE.o
  fi

  if [ "$GCCLINE" != "" ]; then
    GCCLINE=$GCCLINE,
    CLANGLINE=$CLANGLINE,
  fi
  echo "Counting assembler ops in ${FILE}.gcc.S ..."
  GCCVAL=$(python3 count_opcodes.py $FILE.gcc.S)
  GCCLINE=$GCCLINE$GCCVAL
  echo "Counting assembler ops in ${FILE}.clang.S ..."
  CLANGVAL=$(python3 count_opcodes.py $FILE.clang.S)
  CLANGLINE=$CLANGLINE$CLANGVAL

  # We only care about the min_* tests
  if [ "${FILE#min_}" != "$FILE" ]; then
    echo "  <testcase name=\"${FILE}.gcc\">" >> results.xml
    if [ $GCCVAL -gt 5 ] \
         && ([ "$FILE" != "min_monad_construct_error_move_destruct" ] || [ $GCCVAL -gt 10 ]) \
         && ([ "$FILE" != "min_monad_construct_exception_move_destruct" ] || [ $GCCVAL -gt 30 ]) \
      ; then
      echo "    <failure message=\"Opcodes generated $GCCVAL exceeds limit\"/>" >> results.xml
    fi
    echo "    <system-out>" >> results.xml
    echo "<![CDATA[" >> results.xml
    cat $FILE.gcc.S.test1.s >> results.xml
    echo "]]>" >> results.xml
    echo "    </system-out>" >> results.xml
    echo "  </testcase>" >> results.xml

    echo "  <testcase name=\"${FILE}.clang\">" >> results.xml
    if [ $CLANGVAL -gt 5 ]; then
      echo "    <skipped/>" >> results.xml
  #    echo "    <failure message=\"Opcodes generated $CLANGVAL exceeds limit\"/>" >> results.xml
    fi
    echo "    <system-out>" >> results.xml
    echo "<![CDATA[" >> results.xml
    cat $FILE.clang.S.test1.s >> results.xml
    echo "]]>" >> results.xml
    echo "    </system-out>" >> results.xml
    echo "  </testcase>" >> results.xml
  fi
done
echo "</testsuite>" >> results.xml
echo $GCCLINE >> gcc.csv
echo $CLANGLINE >> clang.csv