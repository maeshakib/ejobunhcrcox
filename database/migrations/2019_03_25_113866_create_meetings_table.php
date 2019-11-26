<?php

use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Database\Migrations\Migration;

class CreateMeetingsTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('meetings', function (Blueprint $table) {
            $table->increments('id');
            $table->string('title', 255);
            $table->dateTime('from_date');
            $table->dateTime('to_date');
            $table->text('agenda')->nullable();
            $table->tinyInteger('repeat')->default(0);
            $table->tinyInteger('published')->default(0);
            $table->tinyInteger('meeting_type')->default(0);
            $table->tinyInteger('meeting_status')->default(0);
            $table->text('address')->nullable();
            $table->text('lat_lng')->nullable();
            $table->text('file')->nullable();
            $table->text('image')->nullable();
            $table->text('remarks')->nullable();
            $table->unsignedInteger('created_by');
            $table->unsignedInteger('created_for');

            $table->timestamps();
            $table->foreign('created_by')->references('id')->on('users');
            $table->foreign('created_for')->references('id')->on('users');

        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('meetings');
    }
}
