<?php

/*
 * Copyright (C) 2026
 * All rights reserved.
 */

namespace OPNsense\Gatus;

class GeneralController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/Gatus/general');
        $this->view->generalForm = $this->getForm("general");
    }
}
