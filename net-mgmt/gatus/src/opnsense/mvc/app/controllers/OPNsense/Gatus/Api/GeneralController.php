<?php

/*
 * Copyright (C) 2026
 * All rights reserved.
 */

namespace OPNsense\Gatus\Api;

use OPNsense\Base\ApiMutableModelControllerBase;

class GeneralController extends ApiMutableModelControllerBase
{
    private const DEFAULT_CONFIG = "web:\n"
        . "  port: 8080\n"
        . "\n"
        . "storage:\n"
        . "  type: sqlite\n"
        . "  path: /usr/local/opnsense/gatus/gatus.db\n"
        . "\n"
        . "endpoints:\n"
        . "  - name: example\n"
        . "    group: default\n"
        . "    url: \"https://example.com/\"\n"
        . "    interval: 5m\n"
        . "    conditions:\n"
        . "      - \"[STATUS] == 200\"\n";

    protected static $internalModelName = 'general';
    protected static $internalModelClass = 'OPNsense\\Gatus\\General';

    public function getAction()
    {
        $result = parent::getAction();
        if (isset($result['general']['config']) && trim((string)$result['general']['config']) === '') {
            $result['general']['config'] = self::DEFAULT_CONFIG;
        }

        return $result;
    }
}
