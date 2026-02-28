<?php

/*
 * Copyright (C) 2026
 * All rights reserved.
 */

namespace OPNsense\Gatus\Api;

use OPNsense\Base\ApiMutableServiceControllerBase;

class ServiceController extends ApiMutableServiceControllerBase
{
    protected static $internalServiceClass = '\\OPNsense\\Gatus\\General';
    protected static $internalServiceEnabled = 'enabled';
    protected static $internalServiceTemplate = 'OPNsense/Gatus';
    protected static $internalServiceName = 'gatus';
}
