<?php

/*
 * Copyright (C) 2026
 * All rights reserved.
 */

function gatus_services()
{
    $services = array();
    $mdlGeneral = new \OPNsense\Gatus\General();

    if ($mdlGeneral->enabled->__toString() == "0") {
        return $services;
    }

    $services[] = array(
        'description' => gettext('Gatus'),
        'configd' => array(
            'restart' => array('gatus restart'),
            'start' => array('gatus start'),
            'stop' => array('gatus stop'),
            'status' => array('gatus status'),
        ),
        'name' => 'gatus',
        'pidfile' => '/var/run/gatus.pid'
    );

    return $services;
}
