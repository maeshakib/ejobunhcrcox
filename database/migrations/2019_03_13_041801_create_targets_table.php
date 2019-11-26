<?php

use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Database\Migrations\Migration;

class CreateTargetsTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('targets', function (Blueprint $table) {
            $table->increments('id');
            $table->unsignedInteger('created_by');
            $table->unsignedInteger('user_id');
            $table->tinyInteger('type');
            $table->dateTime('from_date');
            $table->dateTime('to_date');
            $table->float('target_amount', 20, 2);
            $table->string('note')->nullable();   
            $table->timestamps();
            $table->foreign('created_by')->references('id')->on('users');
            $table->foreign('user_id')->references('id')->on('users');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('targets');
    }
}
