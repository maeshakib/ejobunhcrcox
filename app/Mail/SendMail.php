<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;
use Illuminate\Contracts\Queue\ShouldQueue;

class SendMail extends Mailable
{
    use Queueable, SerializesModels;

    /**
     * Create a new message instance.
     *
     * @return void
     */
    public function __construct($dd)
    {
        $this->dd=$dd;
    }

    /**
     * Build the message.
     *
     * @return $this
     */
    public function build()
    {
        $contractor = $this->dd;

        return $this->view('mail',compact('contractor'))->subject('UNHCR,Coxsbazar password reset instructions');
    }
}
