use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	   => 'Email::Valid',
    'VERSION_FROM' => 'Valid.pm', 
    'dist'      => {'COMPRESS'=>'gzip -9f', 'SUFFIX' => 'gz',
                    'ZIP'=>'/usr/bin/zip','ZIPFLAGS'=>'-rl'}
);
