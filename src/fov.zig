const std = @import("std");
const math = std.math;
const assert = std.debug.assert;

const state = @import("state.zig");
const utils = @import("utils.zig");
usingnamespace @import("types.zig");

// Memoized values for {sin,cos}(ray_number * PI / 180). Optimization.
// TODO: figure out a way to populate these arrays with a comptime expression.
//
// zig fmt: off
const sintable: [361]f64 = [_]f64{
     0.000000000000000000,  0.017452406437283512,  0.034899496702500969,
     0.052335956242943828,  0.069756473744125302,  0.087155742747658166,
     0.104528463267653457,  0.121869343405147476,  0.139173100960065438,
     0.156434465040230869,  0.173648177666930331,  0.190808995376544804,
     0.207911690817759315,  0.224951054343865003,  0.241921895599667730,
     0.258819045102520739,  0.275637355816999163,  0.292371704722736769,
     0.309016994374947396,  0.325568154457156644,  0.342020143325668713,
     0.358367949545300268,  0.374606593415912015,  0.390731128489273716,
     0.406736643075800153,  0.422618261740699441,  0.438371146789077404,
     0.453990499739546749,  0.469471562785890806,  0.484809620246337059,
     0.499999999999999944,  0.515038074910054156,  0.529919264233204901,
     0.544639035015027084,  0.559192903470746905,  0.573576436351046048,
     0.587785252292473137,  0.601815023152048267,  0.615661475325658181,
     0.629320391049837391,  0.642787609686539252,  0.656059028990507165,
     0.669130606358858238,  0.681998360062498477,  0.694658370458997254,
     0.707106781186547462,  0.719339800338651081,  0.731353701619170460,
     0.743144825477394244,  0.754709580222772014,  0.766044443118978013,
     0.777145961456970791,  0.788010753606722014,  0.798635510047292829,
     0.809016994374947451,  0.819152044288991799,  0.829037572555041735,
     0.838670567945423939,  0.848048096156425957,  0.857167300702112223,
     0.866025403784438597,  0.874619707139395741,  0.882947592858926877,
     0.891006524188367788,  0.898794046299167038,  0.906307787036649937,
     0.913545457642600867,  0.920504853452440264,  0.927183854566787424,
     0.933580426497201743,  0.939692620785908317,  0.945518575599316735,
     0.951056516295153531,  0.956304755963035436,  0.961261695938318894,
     0.965925826289068312,  0.970295726275996473,  0.974370064785235246,
     0.978147600733805578,  0.981627183447663976,  0.984807753012208020,
     0.987688340595137770,  0.990268068741570251,  0.992546151641321983,
     0.994521895368273290,  0.996194698091745545,  0.997564050259824198,
     0.998629534754573833,  0.999390827019095762,  0.999847695156391270,
     1.000000000000000000,  0.999847695156391270,  0.999390827019095762,
     0.998629534754573833,  0.997564050259824198,  0.996194698091745545,
     0.994521895368273401,  0.992546151641322094,  0.990268068741570362,
     0.987688340595137659,  0.984807753012208020,  0.981627183447663976,
     0.978147600733805689,  0.974370064785235246,  0.970295726275996473,
     0.965925826289068312,  0.961261695938318894,  0.956304755963035547,
     0.951056516295153642,  0.945518575599316846,  0.939692620785908428,
     0.933580426497201743,  0.927183854566787424,  0.920504853452440375,
     0.913545457642600978,  0.906307787036650048,  0.898794046299166927,
     0.891006524188367899,  0.882947592858927099,  0.874619707139395852,
     0.866025403784438708,  0.857167300702112334,  0.848048096156426068,
     0.838670567945423939,  0.829037572555041735,  0.819152044288992021,
     0.809016994374947451,  0.798635510047292718,  0.788010753606722014,
     0.777145961456971013,  0.766044443118978013,  0.754709580222771792,
     0.743144825477394244,  0.731353701619170571,  0.719339800338651414,
     0.707106781186547573,  0.694658370458997143,  0.681998360062498588,
     0.669130606358858349,  0.656059028990507276,  0.642787609686539474,
     0.629320391049837724,  0.615661475325658403,  0.601815023152048156,
     0.587785252292473248,  0.573576436351046381,  0.559192903470746905,
     0.544639035015026973,  0.529919264233204901,  0.515038074910054378,
     0.499999999999999944,  0.484809620246337170,  0.469471562785891083,
     0.453990499739546860,  0.438371146789077293,  0.422618261740699497,
     0.406736643075800430,  0.390731128489274160,  0.374606593415912237,
     0.358367949545300213,  0.342020143325668879,  0.325568154457157033,
     0.309016994374947507,  0.292371704722737047,  0.275637355816999663,
     0.258819045102521017,  0.241921895599667730,  0.224951054343864781,
     0.207911690817759315,  0.190808995376544971,  0.173648177666930276,
     0.156434465040230980,  0.139173100960065743,  0.121869343405147545,
     0.104528463267653735,  0.087155742747658638,  0.069756473744125524,
     0.052335956242943807,  0.034899496702500699,  0.017452406437283439,
     0.000000000000000122, -0.017452406437283192, -0.034899496702500900,
    -0.052335956242943564, -0.069756473744124831, -0.087155742747657944,
    -0.104528463267653055, -0.121869343405147740, -0.139173100960065521,
    -0.156434465040230730, -0.173648177666930470, -0.190808995376544721,
    -0.207911690817759065, -0.224951054343864976, -0.241921895599667508,
    -0.258819045102520351, -0.275637355816998997, -0.292371704722736381,
    -0.309016994374947729, -0.325568154457156755, -0.342020143325668657,
    -0.358367949545300435, -0.374606593415912015, -0.390731128489273549,
    -0.406736643075799820, -0.422618261740699275, -0.438371146789077071,
    -0.453990499739546249, -0.469471562785890861, -0.484809620246336948,
    -0.500000000000000111, -0.515038074910054156, -0.529919264233204790,
    -0.544639035015027084, -0.559192903470746683, -0.573576436351045826,
    -0.587785252292473026, -0.601815023152048045, -0.615661475325657848,
    -0.629320391049837613, -0.642787609686539252, -0.656059028990507387,
    -0.669130606358858238, -0.681998360062498366, -0.694658370458997365,
    -0.707106781186547462, -0.719339800338650859, -0.731353701619170127,
    -0.743144825477394022, -0.754709580222771681, -0.766044443118977902,
    -0.777145961456971124, -0.788010753606722125, -0.798635510047292829,
    -0.809016994374947340, -0.819152044288991577, -0.829037572555041402,
    -0.838670567945424050, -0.848048096156425957, -0.857167300702112112,
    -0.866025403784438375, -0.874619707139395963, -0.882947592858926988,
    -0.891006524188367788, -0.898794046299166816, -0.906307787036649715,
    -0.913545457642600978, -0.920504853452440264, -0.927183854566787313,
    -0.933580426497201632, -0.939692620785908206, -0.945518575599316846,
    -0.951056516295153531, -0.956304755963035324, -0.961261695938319005,
    -0.965925826289068312, -0.970295726275996473, -0.974370064785235135,
    -0.978147600733805578, -0.981627183447663865, -0.984807753012208020,
    -0.987688340595137659, -0.990268068741570362, -0.992546151641322094,
    -0.994521895368273401, -0.996194698091745545, -0.997564050259824198,
    -0.998629534754573833, -0.999390827019095651, -0.999847695156391270,
    -1.000000000000000000, -0.999847695156391270, -0.999390827019095762,
    -0.998629534754573833, -0.997564050259824309, -0.996194698091745545,
    -0.994521895368273401, -0.992546151641321983, -0.990268068741570362,
    -0.987688340595137770, -0.984807753012208131, -0.981627183447664087,
    -0.978147600733805800, -0.974370064785235246, -0.970295726275996584,
    -0.965925826289068201, -0.961261695938318783, -0.956304755963035436,
    -0.951056516295153642, -0.945518575599316957, -0.939692620785908539,
    -0.933580426497202076, -0.927183854566787424, -0.920504853452440486,
    -0.913545457642600756, -0.906307787036649937, -0.898794046299167038,
    -0.891006524188367899, -0.882947592858927099, -0.874619707139396074,
    -0.866025403784438597, -0.857167300702112334, -0.848048096156426179,
    -0.838670567945424272, -0.829037572555042068, -0.819152044288991799,
    -0.809016994374947562, -0.798635510047293051, -0.788010753606721792,
    -0.777145961456970791, -0.766044443118978124, -0.754709580222772236,
    -0.743144825477394577, -0.731353701619171015, -0.719339800338651747,
    -0.707106781186547684, -0.694658370458997587, -0.681998360062498254,
    -0.669130606358858127, -0.656059028990507387, -0.642787609686539585,
    -0.629320391049837835, -0.615661475325658847, -0.601815023152048267,
    -0.587785252292473359, -0.573576436351046492, -0.559192903470747349,
    -0.544639035015026973, -0.529919264233205789, -0.515038074910054489,
    -0.500000000000000444, -0.484809620246336892, -0.469471562785890806,
    -0.453990499739546971, -0.438371146789077015, -0.422618261740699996,
    -0.406736643075800153, -0.390731128489274715, -0.374606593415912348,
    -0.358367949545300768, -0.342020143325668602, -0.325568154457157533,
    -0.309016994374947673, -0.292371704722736270, -0.275637355816999774,
    -0.258819045102520684, -0.241921895599667869, -0.224951054343865336,
    -0.207911690817759870, -0.190808995376544666, -0.173648177666931275,
    -0.156434465040231119, -0.139173100960065882, -0.121869343405148114,
    -0.104528463267653415, -0.087155742747658319, -0.069756473744124761,
    -0.052335956242944369, -0.034899496702500823, -0.017452406437284448,
    -0.000000000000000245,
};

const costable: [361]f64 = [_]f64{
     1.000000000000000000,  0.999847695156391270,  0.999390827019095762,
     0.998629534754573833,  0.997564050259824198,  0.996194698091745545,
     0.994521895368273290,  0.992546151641321983,  0.990268068741570362,
     0.987688340595137770,  0.984807753012208020,  0.981627183447663976,
     0.978147600733805689,  0.974370064785235246,  0.970295726275996473,
     0.965925826289068312,  0.961261695938318894,  0.956304755963035436,
     0.951056516295153531,  0.945518575599316846,  0.939692620785908428,
     0.933580426497201743,  0.927183854566787424,  0.920504853452440375,
     0.913545457642600867,  0.906307787036649937,  0.898794046299167038,
     0.891006524188367899,  0.882947592858926988,  0.874619707139395741,
     0.866025403784438708,  0.857167300702112334,  0.848048096156425957,
     0.838670567945424050,  0.829037572555041624,  0.819152044288991799,
     0.809016994374947451,  0.798635510047292829,  0.788010753606722014,
     0.777145961456970902,  0.766044443118978013,  0.754709580222772125,
     0.743144825477394244,  0.731353701619170571,  0.719339800338651192,
     0.707106781186547573,  0.694658370458997365,  0.681998360062498477,
     0.669130606358858238,  0.656059028990507276,  0.642787609686539363,
     0.629320391049837502,  0.615661475325658292,  0.601815023152048378,
     0.587785252292473137,  0.573576436351046159,  0.559192903470746794,
     0.544639035015027195,  0.529919264233204901,  0.515038074910054378,
     0.500000000000000111,  0.484809620246337114,  0.469471562785890861,
     0.453990499739546804,  0.438371146789077459,  0.422618261740699441,
     0.406736643075800208,  0.390731128489273938,  0.374606593415911959,
     0.358367949545300379,  0.342020143325668824,  0.325568154457156755,
     0.309016994374947451,  0.292371704722736769,  0.275637355816999163,
     0.258819045102520739,  0.241921895599667897,  0.224951054343864920,
     0.207911690817759454,  0.190808995376544915,  0.173648177666930414,
     0.156434465040230924,  0.139173100960065688,  0.121869343405147490,
     0.104528463267653457,  0.087155742747658138,  0.069756473744125455,
     0.052335956242943966,  0.034899496702501080,  0.017452406437283376,
     0.000000000000000061, -0.017452406437283477, -0.034899496702500733,
    -0.052335956242943620, -0.069756473744125330, -0.087155742747658235,
    -0.104528463267653332, -0.121869343405147365, -0.139173100960065355,
    -0.156434465040231035, -0.173648177666930303, -0.190808995376544804,
    -0.207911690817759121, -0.224951054343864809, -0.241921895599667786,
    -0.258819045102520850, -0.275637355816999052, -0.292371704722736658,
    -0.309016994374947340, -0.325568154457156422, -0.342020143325668713,
    -0.358367949545300268, -0.374606593415912070, -0.390731128489273605,
    -0.406736643075800042, -0.422618261740699330, -0.438371146789077515,
    -0.453990499739546693, -0.469471562785890528, -0.484809620246337003,
    -0.499999999999999778, -0.515038074910054267, -0.529919264233204790,
    -0.544639035015027084, -0.559192903470746683, -0.573576436351045826,
    -0.587785252292473026, -0.601815023152048378, -0.615661475325658292,
    -0.629320391049837280, -0.642787609686539363, -0.656059028990507498,
    -0.669130606358858238, -0.681998360062498366, -0.694658370458997032,
    -0.707106781186547462, -0.719339800338651192, -0.731353701619170460,
    -0.743144825477394022, -0.754709580222772014, -0.766044443118977902,
    -0.777145961456970680, -0.788010753606721903, -0.798635510047292940,
    -0.809016994374947340, -0.819152044288991577, -0.829037572555041624,
    -0.838670567945424161, -0.848048096156425957, -0.857167300702112223,
    -0.866025403784438708, -0.874619707139395741, -0.882947592858926766,
    -0.891006524188367788, -0.898794046299167038, -0.906307787036649937,
    -0.913545457642600756, -0.920504853452440153, -0.927183854566787313,
    -0.933580426497201743, -0.939692620785908317, -0.945518575599316735,
    -0.951056516295153531, -0.956304755963035436, -0.961261695938318672,
    -0.965925826289068201, -0.970295726275996473, -0.974370064785235246,
    -0.978147600733805689, -0.981627183447663976, -0.984807753012208020,
    -0.987688340595137659, -0.990268068741570251, -0.992546151641321983,
    -0.994521895368273290, -0.996194698091745545, -0.997564050259824198,
    -0.998629534754573833, -0.999390827019095762, -0.999847695156391270,
    -1.000000000000000000, -0.999847695156391270, -0.999390827019095762,
    -0.998629534754573833, -0.997564050259824309, -0.996194698091745545,
    -0.994521895368273401, -0.992546151641321983, -0.990268068741570251,
    -0.987688340595137770, -0.984807753012208020, -0.981627183447663976,
    -0.978147600733805689, -0.974370064785235246, -0.970295726275996473,
    -0.965925826289068423, -0.961261695938318894, -0.956304755963035547,
    -0.951056516295153531, -0.945518575599316735, -0.939692620785908428,
    -0.933580426497201743, -0.927183854566787424, -0.920504853452440375,
    -0.913545457642601089, -0.906307787036650048, -0.898794046299167149,
    -0.891006524188368121, -0.882947592858926877, -0.874619707139395852,
    -0.866025403784438597, -0.857167300702112334, -0.848048096156426068,
    -0.838670567945424050, -0.829037572555041846, -0.819152044288992021,
    -0.809016994374947562, -0.798635510047293051, -0.788010753606722236,
    -0.777145961456970791, -0.766044443118978013, -0.754709580222771903,
    -0.743144825477394244, -0.731353701619170571, -0.719339800338651081,
    -0.707106781186547684, -0.694658370458997587, -0.681998360062498921,
    -0.669130606358858460, -0.656059028990507609, -0.642787609686539474,
    -0.629320391049837169, -0.615661475325658070, -0.601815023152048267,
    -0.587785252292473248, -0.573576436351046381, -0.559192903470747238,
    -0.544639035015026973, -0.529919264233205012, -0.515038074910054489,
    -0.500000000000000444, -0.484809620246336836, -0.469471562785890750,
    -0.453990499739546916, -0.438371146789077737, -0.422618261740699941,
    -0.406736643075800097, -0.390731128489273827, -0.374606593415912292,
    -0.358367949545300712, -0.342020143325669379, -0.325568154457156644,
    -0.309016994374947562, -0.292371704722737102, -0.275637355816998886,
    -0.258819045102520628, -0.241921895599667786, -0.224951054343865253,
    -0.207911690817759787, -0.190808995376545470, -0.173648177666930331,
    -0.156434465040231035, -0.139173100960064938, -0.121869343405147171,
    -0.104528463267653360, -0.087155742747658249, -0.069756473744125580,
    -0.052335956242944306, -0.034899496702501649, -0.017452406437283498,
    -0.000000000000000184,  0.017452406437283130,  0.034899496702501281,
     0.052335956242943946,  0.069756473744125219,  0.087155742747657888,
     0.104528463267652985,  0.121869343405147684,  0.139173100960065466,
     0.156434465040230675,  0.173648177666929970,  0.190808995376544249,
     0.207911690817758565,  0.224951054343864920,  0.241921895599667452,
     0.258819045102521128,  0.275637355816999385,  0.292371704722736714,
     0.309016994374947229,  0.325568154457156311,  0.342020143325668158,
     0.358367949545299547,  0.374606593415911959,  0.390731128489273494,
     0.406736643075800541,  0.422618261740699608,  0.438371146789077404,
     0.453990499739546638,  0.469471562785890417,  0.484809620246336503,
     0.500000000000000111,  0.515038074910054156,  0.529919264233204679,
     0.544639035015026640,  0.559192903470746239,  0.573576436351046048,
     0.587785252292472915,  0.601815023152047934,  0.615661475325658514,
     0.629320391049837502,  0.642787609686539252,  0.656059028990507054,
     0.669130606358857793,  0.681998360062498032,  0.694658370458996588,
     0.707106781186547351,  0.719339800338650859,  0.731353701619170682,
     0.743144825477394244,  0.754709580222771903,  0.766044443118977791,
     0.777145961456970569,  0.788010753606721570,  0.798635510047292829,
     0.809016994374947340,  0.819152044288991577,  0.829037572555041402,
     0.838670567945424050,  0.848048096156425402,  0.857167300702112112,
     0.866025403784438375,  0.874619707139395852,  0.882947592858926877,
     0.891006524188367788,  0.898794046299167149,  0.906307787036649715,
     0.913545457642600978,  0.920504853452439931,  0.927183854566787313,
     0.933580426497201521,  0.939692620785908428,  0.945518575599316513,
     0.951056516295153531,  0.956304755963035658,  0.961261695938318672,
     0.965925826289068312,  0.970295726275996473,  0.974370064785235135,
     0.978147600733805578,  0.981627183447663976,  0.984807753012207909,
     0.987688340595137659,  0.990268068741570251,  0.992546151641321983,
     0.994521895368273290,  0.996194698091745545,  0.997564050259824309,
     0.998629534754573833,  0.999390827019095762,  0.999847695156391270,
     1.000000000000000000,
};
// zig fmt: on

pub fn rayCast(
    center: Coord,
    radius: usize,
    energy: usize,
    opacity_func: fn (Coord) usize,
    buffer: *[HEIGHT][WIDTH]usize,
    direction: Direction,
) void {
    // Area of quadrant coverage by each direction:
    //
    //                     180
    //                    North
    //                225   |    135
    //                 \0000|3333/
    //                 1\000|333/2
    //                 11\00|33/22
    //                 111\0|3/222
    //                 1111\|/2222
    //        270 West -----@------ East 90
    //                 6666/|\5555
    //                 666/7|4\555
    //                 66/77|44\55
    //                 6/777|444\5
    //                 /7777|4444\
    //               315    |    45
    //                    South
    //                    360 0
    //
    //
    const quadrant: [4]usize = switch (direction) {
        .South => [_]usize{ 315, 360, 0, 45 },
        .SouthEast => [_]usize{ 0, 45, 45, 90 },
        .East => [_]usize{ 45, 90, 90, 135 },
        .NorthEast => [_]usize{ 90, 135, 135, 180 },
        .North => [_]usize{ 135, 180, 180, 225 },
        .NorthWest => [_]usize{ 180, 225, 225, 270 },
        .West => [_]usize{ 225, 270, 270, 315 },
        .SouthWest => [_]usize{ 270, 315, 315, 360 },
    };

    rayCastOctants(center, radius, energy, opacity_func, buffer, quadrant[0], quadrant[1]);
    rayCastOctants(center, radius, energy, opacity_func, buffer, quadrant[2], quadrant[3]);

    const x_min = utils.saturating_sub(center.x, radius);
    const y_min = utils.saturating_sub(center.y, radius);
    const x_max = math.clamp(center.x + radius + 1, 0, WIDTH - 1);
    const y_max = math.clamp(center.y + radius + 1, 0, HEIGHT - 1);

    _removeArtifacts(center.z, x_min, y_min, center.x, center.y, -1, -1, buffer, opacity_func);
    _removeArtifacts(center.z, center.x, y_min, x_max - 1, center.y, 1, -1, buffer, opacity_func);
    _removeArtifacts(center.z, x_min, center.y, center.x, y_max - 1, -1, 1, buffer, opacity_func);
    _removeArtifacts(center.z, center.x, center.y, x_max - 1, y_max - 1, 1, 1, buffer, opacity_func);

    buffer[center.y][center.x] = 100;
}

pub fn rayCastOctants(
    center: Coord,
    radius: usize,
    energy: usize,
    opacity_func: fn (Coord) usize,
    buffer: *[HEIGHT][WIDTH]usize,
    start: usize,
    end: usize,
) void {
    var i = start;
    while (i < end) : (i += 1) {
        const ax = sintable[i];
        const ay = costable[i];

        var x = @intToFloat(f64, center.x);
        var y = @intToFloat(f64, center.y);

        var ray_energy: usize = energy;
        var z: usize = 0;
        while (z < radius) : (z += 1) {
            x += ax;
            y += ay;

            if (x < 0 or y < 0) break;

            const ix = @floatToInt(usize, math.round(x));
            const iy = @floatToInt(usize, math.round(y));
            const coord = Coord.new2(center.z, ix, iy);

            if (ix >= state.mapgeometry.x or iy >= state.mapgeometry.y)
                break;

            const previous_energy = buffer[coord.y][coord.x];
            const energy_percent = ray_energy * 100 / energy;
            if (energy_percent > previous_energy) {
                buffer[coord.y][coord.x] = energy_percent;
            }

            ray_energy = utils.saturating_sub(ray_energy, opacity_func(coord));
            if (ray_energy == 0) break;
        }
    }

    buffer[center.y][center.x] = 100;
}

// Much thanks to libtcod! :>
fn _removeArtifacts(
    z: usize,
    x0: usize,
    y0: usize,
    x1: usize,
    y1: usize,
    dx: isize,
    dy: isize,
    buffer: *[HEIGHT][WIDTH]usize,
    opacity_func: fn (Coord) usize,
) void {
    assert((math.absInt(dx) catch unreachable) == 1);
    assert((math.absInt(dy) catch unreachable) == 1);

    var cx: usize = x0;
    while (cx < x1) : (cx += 1) {
        var cy: usize = y0;
        while (cy < y1) : (cy += 1) {
            const x2 = @intCast(isize, cx) + dx;
            const y2 = @intCast(isize, cy) + dy;

            if (cx >= WIDTH or cy >= HEIGHT) {
                continue;
            }

            if (buffer[cy][cx] > 0 and opacity_func(Coord.new2(z, cx, cy)) < 100) {
                if (x2 >= @intCast(isize, x0) and x2 <= @intCast(isize, x1)) {
                    const cx2 = @intCast(usize, x2);
                    if (cx2 < WIDTH and cy < HEIGHT and opacity_func(Coord.new2(z, cx2, cy)) >= 100) {
                        buffer[cy][cx2] = math.max(buffer[cy][cx2], buffer[cy][cx]);
                    }
                }

                if (@intCast(isize, y2) >= y0 and @intCast(isize, y2) <= y1) {
                    const cy2 = @intCast(usize, y2);
                    if (cx < WIDTH and cy2 < HEIGHT and opacity_func(Coord.new2(z, cx, cy2)) >= 100) {
                        buffer[cy2][cx] = math.max(buffer[cy2][cx], buffer[cy][cx]);
                    }
                }

                if (@intCast(usize, x2) >= x0 and
                    @intCast(isize, x2) <= x1 and
                    @intCast(usize, y2) >= y0 and
                    @intCast(usize, y2) <= y1)
                {
                    const cx2 = @intCast(usize, x2);
                    const cy2 = @intCast(usize, y2);
                    if (cx2 < WIDTH and cy2 < HEIGHT and opacity_func(Coord.new2(z, cx2, cy2)) >= 100) {
                        buffer[cy2][cx2] = math.max(buffer[cy2][cx2], buffer[cy][cx]);
                    }
                }
            }
        }
    }
}
