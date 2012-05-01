#!/usr/bin/env php
<?php

/*
 * This file is part of Composer.
 *
 * (c) Nils Adermann <naderman@naderman.de>
 *     Jordi Boggiano <j.boggiano@seld.be>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

process($argv);

/**
 * processes the installer
 */
function process($argv)
{
    $check      = in_array('--check', $argv);
    $help       = in_array('--help', $argv);
    $force      = in_array('--force', $argv);
    $installDir = false;
    foreach ($argv as $val) {
        if (0 === strpos($val, '--install-dir')) {
            $installDir = trim(substr($val, 14));
        }
    }

    if ($help) {
        displayHelp();
        exit(0);
    }

    $ok = checkPlatform();

    if ($installDir && !realpath($installDir)) {
        out("The defined install dir ({$installDir}) does not exist.".PHP_EOL, 'info');
        $ok = false;
    }

    if ($check) {
        exit($ok ? 0 : 1);
    }

    if ($ok || $force) {
        installComposer($installDir);
    }

    exit(0);
}

/**
 * displays the help
 */
function displayHelp()
{
    echo <<<EOF
Composer Installer
------------------
Options
--help               this help
--check              for checking environment only
--force              forces the installation
--install-dir="..."  accepts a target installation directory

EOF;
}

/**
 * check the platform for possible issues on running composer
 */
function checkPlatform()
{
    $errors = array();
    $warnings = array();
    if (ini_get('detect_unicode')) {
        $errors['unicode'] = 'On';
    }

    $suhosin = ini_get('suhosin.executor.include.whitelist');
    if (false !== $suhosin && false === stripos($suhosin, 'phar')) {
        $errors['suhosin'] = $suhosin;
    }

    if (!ini_get('allow_url_fopen')) {
        $errors['allow_url_fopen'] = true;
    }

    if (extension_loaded('ionCube Loader')) {
        $errors['ioncube'] = true;
    }

    if (version_compare(PHP_VERSION, '5.3.2', '<')) {
        $errors['php'] = PHP_VERSION;
    }

    if (ini_get('apc.enable_cli')) {
        $warnings['apc_cli'] = true;
    }

    if (!empty($errors)) {
        out("Some settings on your machine make Composer unable to work properly.".PHP_EOL, 'error');

        out('Make sure that you fix the issues listed below and run this script again:'.PHP_EOL, 'error');
        foreach ($errors as $error => $current) {
            switch ($error) {
                case 'unicode':
                    $text = PHP_EOL."The detect_unicode setting must be disabled.".PHP_EOL;
                    $text .= "Add the following to the end of your `php.ini`:".PHP_EOL;
                    $text .= "    detect_unicode = Off".PHP_EOL;
                    break;

                case 'suhosin':
                    $text = PHP_EOL."The suhosin.executor.include.whitelist setting is incorrect.".PHP_EOL;
                    $text .= "Add the following to the end of your `php.ini`:".PHP_EOL;
                    $text .= "    suhosin.executor.include.whitelist = phar ".$current.PHP_EOL;
                    break;

                case 'php':
                    $text = PHP_EOL."Your PHP ({$current}) is too old, you must upgrade to PHP 5.3.2 or higher.".PHP_EOL;
                    break;

                case 'allow_url_fopen':
                    $text = PHP_EOL."The allow_url_fopen setting is incorrect.".PHP_EOL;
                    $text .= "Add the following to the end of your `php.ini`:".PHP_EOL;
                    $text .= "    allow_url_fopen = On".PHP_EOL;
                    break;

                case 'ioncube':
                    $text = PHP_EOL."The ionCube Loader extension is incompatible with Phar files.".PHP_EOL;
                    $text .= "Remove this line (path may be different) from your `php.ini`:".PHP_EOL;
                    $text .= "    zend_extension = /usr/lib/php5/20090626+lfs/ioncube_loader_lin_5.3.so".PHP_EOL;
                    break;
            }
            out($text, 'info');
        }
        echo PHP_EOL;
        return false;
    }

    if (!empty($warnings)) {
        out("Some settings on your machine may cause stability issues with Composer.".PHP_EOL, 'error');

        out('If you encounter issues, try to change the following:'.PHP_EOL, 'error');
        foreach ($warnings as $warning => $current) {
            switch ($warning) {
                case 'apc_cli':
                    $text = PHP_EOL."The apc.enable_cli setting is incorrect.".PHP_EOL;
                    $text .= "Add the following to the end of your `php.ini`:".PHP_EOL;
                    $text .= "    apc.enable_cli = Off".PHP_EOL;
                    break;
            }
            out($text, 'info');
        }
        echo PHP_EOL;
        return true;
    }

    out("All settings correct for using Composer".PHP_EOL, 'success');
    return true;
}

/**
 * installs composer to the current working directory
 */
function installComposer($installDir)
{
    $installDir = realpath($installDir) ? realpath($installDir) : getcwd();
    $file       = $installDir.DIRECTORY_SEPARATOR.'composer.phar';

    if (is_readable($file)) {
        @unlink($file);
    }

    $retries = 3;
    while ($retries--) {
        out("Downloading...".PHP_EOL, 'info');
        copy('http://getcomposer.org/composer.phar', $file);
        try {
            // test the phar validity
            $phar = new Phar($file);
            // free the variable to unlock the file
            unset($phar);
            break;
        } catch (Exception $e) {
            if (!$e instanceof UnexpectedValueException && !$e instanceof PharException) {
                throw $e;
            }
            unlink($file);
            if ($retries) {
                out('The download is corrupt, retrying...'.PHP_EOL, 'error');
            } else {
                out('The download is corrupt ('.$e->getMessage().'), aborting.'.PHP_EOL, 'error');
                exit(1);
            }
        }
    }
    chmod($file, 0755);

    out(PHP_EOL."Composer successfully installed to: " . $file, 'success');
    out(PHP_EOL."Use it: php composer.phar".PHP_EOL, 'info');
}

/**
 * colorize output
 */
function out($text, $color = null)
{
    $styles = array(
        'success' => "\033[0;32m%s\033[0m",
        'error' => "\033[31;31m%s\033[0m",
        'info' => "\033[33;33m%s\033[0m"
    );

    echo sprintf(isset($styles[$color]) ? $styles[$color] : "%s", $text);
}
