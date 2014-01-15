code = "5::second + now => time later;\n" +
  "while( now < later )\n" +
  "{\n" +
  "    <<<now>>>;\n" +
  "    1::second => now;\n" +
  "}\n" +
  "<<<now>>>;\n";