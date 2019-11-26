<?php

use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Database\Migrations\Migration;

class CreateUserAttendancesTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('user_attendances', function (Blueprint $table) {
            $table->increments('id');
            $table->unsignedInteger('user_id');
            $table->date('date');
            $table->time('cin_time')->nullable();
            $table->time('cout_time')->nullable();
            $table->string('cin_latlng')->nullable();
            $table->string('cout_latlng')->nullable();
            $table->string('cin_area')->nullable();
            $table->string('cout_area')->nullable();
            $table->string('remarks')->nullable();
            $table->text('locations')->nullable();

            $table->timestamps();
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
        Schema::dropIfExists('user_attendances');
    }
}
