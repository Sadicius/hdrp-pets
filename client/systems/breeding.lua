-- HDRP-PETS: Eventos de feedback de cría (cliente)
-- Este archivo gestiona los eventos de feedback tras la cría

RegisterNetEvent('hdrp-pets:client:breedingstarted', function(petAId, petBId)
end)

RegisterNetEvent('hdrp-pets:client:newoffspring', function(offspringId, offspringData)
    lib.notify({
        title = locale('cl_breed_born_title'),
        description = locale('cl_breed_born_description'),
        type = 'success',
        duration = 8000
    })
end)
